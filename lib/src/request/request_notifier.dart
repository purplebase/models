part of models;

/// Global buffer for batching LocalAndRemoteSource queries.
///
/// When multiple queries arrive within [StorageConfiguration.requestBufferDuration],
/// they are collected, merged into fewer relay requests, and sent together.
/// This prevents flooding relays with requests.
///
/// Only LocalAndRemoteSource queries are buffered/merged. RemoteSource queries
/// bypass the buffer to preserve "arrived via this exact subscription" semantics.
class _RemoteQueryBuffer {
  final StorageNotifier storage;
  Timer? _timer;

  /// Pending queries grouped by source key (relay target).
  final Map<String, List<_PendingQuery>> _pending = {};

  _RemoteQueryBuffer(this.storage);

  /// Buffer a query for batched execution.
  ///
  /// Only LocalAndRemoteSource non-streaming queries are buffered.
  /// All other queries go directly to storage.
  ///
  /// Returns the models from the query. For non-buffered queries (RemoteSource,
  /// streaming LocalAndRemoteSource), returns the actual models. For buffered
  /// queries (LocalAndRemoteSource non-streaming), returns empty list since
  /// those notifiers refresh from local storage via InternalStorageData.
  Future<List<Model<dynamic>>> bufferQuery(
    Request request,
    RemoteSource source,
    String? subscriptionPrefix,
  ) {
    // Only buffer non-streaming LocalAndRemoteSource queries.
    // - Streaming queries need their original subscription IDs
    // - RemoteSource needs exact subscription semantics (no merging)
    final shouldBuffer = source is LocalAndRemoteSource && !source.stream;

    if (!shouldBuffer) {
      // Return models directly for non-buffered queries (RemoteSource, streaming)
      return storage.query(
        request,
        source: source,
        subscriptionPrefix: subscriptionPrefix,
      );
    }

    final completer = Completer<List<Model<dynamic>>>();
    final key = _sourceKey(source);

    _pending
        .putIfAbsent(key, () => [])
        .add(
          _PendingQuery(
            request: request,
            source: source,
            subscriptionPrefix: subscriptionPrefix,
            completer: completer,
          ),
        );

    // Reset timer on each new request
    _timer?.cancel();

    final bufferDuration = storage.config.requestBufferDuration;
    if (bufferDuration == Duration.zero) {
      _flush();
    } else {
      _timer = Timer(bufferDuration, _flush);
    }

    return completer.future;
  }

  /// Create a key for grouping sources that can be merged.
  String _sourceKey(RemoteSource source) {
    // Canonicalize relay set for stable keys
    String relays;
    if (source.relays == null) {
      relays = 'outbox';
    } else if (source.relays is Iterable) {
      final list = (source.relays as Iterable).map((e) => e.toString()).toList()
        ..sort();
      relays = list.join(',');
    } else {
      relays = source.relays.toString();
    }
    return 'local_and_remote:$relays';
  }

  /// Flush all pending queries, merging where possible.
  void _flush() {
    if (_pending.isEmpty) return;

    final pendingSnapshot = Map<String, List<_PendingQuery>>.from(_pending);
    _pending.clear();

    for (final entry in pendingSnapshot.entries) {
      final queries = entry.value;
      if (queries.isEmpty) continue;

      // Merge all request filters in this group
      final allFilters = queries.expand((q) => q.request.filters).toList();
      final mergedFilters = RequestFilter.mergeMultiple(allFilters);

      // Use the first query's source (they all have same relay config)
      final source = queries.first.source;
      final basePrefix = queries.first.subscriptionPrefix;

      // Add merged indicator when multiple queries are combined
      final prefix = queries.length > 1
          ? '${basePrefix ?? 'sub'}-merged'
          : basePrefix;

      // Create merged request
      final mergedRequest = mergedFilters.toRequest(subscriptionPrefix: prefix);

      // Execute merged query. For LocalAndRemoteSource, notifiers refresh
      // from local storage on any InternalStorageData update, so they don't
      // need the exact subscription ID - just the data in storage.
      // We complete with empty list since buffered queries don't need models.
      storage
          .query(mergedRequest, source: source, subscriptionPrefix: prefix)
          .then((_) {
            for (final q in queries) {
              if (!q.completer.isCompleted) {
                q.completer.complete(const []);
              }
            }
          })
          .catchError((e, stack) {
            for (final q in queries) {
              if (!q.completer.isCompleted) {
                q.completer.completeError(e, stack);
              }
            }
          });
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}

class _PendingQuery {
  final Request request;
  final RemoteSource source;
  final String? subscriptionPrefix;
  final Completer<List<Model<dynamic>>> completer;

  _PendingQuery({
    required this.request,
    required this.source,
    required this.subscriptionPrefix,
    required this.completer,
  });
}

/// Query buffer instances, one per storage notifier.
/// Uses an Expando to associate buffers with storage instances without
/// preventing garbage collection.
final Expando<_RemoteQueryBuffer> _queryBuffers = Expando();

_RemoteQueryBuffer _getQueryBuffer(StorageNotifier storage) {
  return _queryBuffers[storage] ??= _RemoteQueryBuffer(storage);
}

/// A request notifier takes a [Request] that it uses to query and filter
/// incoming events from [StorageNotifier].
///
/// Behavior varies by source type:
/// - [LocalSource]: emit immediately, even if empty
/// - [LocalAndRemoteSource]: emit local immediately if non-empty, then emit
///   batches at each EOSE (or timeout)
/// - [RemoteSource]: emit exactly the models that came in via subscriptions
///   (not pre-existing local data)
class RequestNotifier<E extends Model<dynamic>>
    extends StateNotifier<StorageState<E>> {
  final Ref ref;
  final Request<E> req;
  final Source source;
  final StorageNotifier storage;

  /// Tracks model.id -> event.id for processed models.
  /// Used to detect updated replaceable models (same model.id, new event.id)
  /// which need their relationships re-queried.
  /// Bounded: one entry per model, not per event.
  final Map<String, String> _processedModelEventIds = {};

  /// Tracks streaming nested query requests (by Request equality, before prefixing).
  /// Maps the unprefixed Request to its prefixed version for cancellation.
  final Map<Request, Request> _streamingRequestToPrefixed = {};

  /// All relationship requests that have been issued (for cancellation).
  final List<Request> _relationshipRequests = [];

  /// Exposed for testing - all relationship requests issued.
  List<Request> get relationshipRequests => _relationshipRequests;

  /// Counter for total relationship queries issued (for testing).
  /// Unlike relationshipRequests.length, this only increases.
  int _totalRelationshipQueriesIssued = 0;

  /// Exposed for testing - total relationship queries issued.
  int get totalRelationshipQueriesIssued => _totalRelationshipQueriesIssued;

  /// Tracks nested queries with `and` callbacks, keyed by their prefixed request.
  /// When relationship data arrives via subscription, we look up the NestedQuery
  /// to process its nested callbacks. Stores (NestedQuery, resolvedSource) tuple
  /// so deeply nested queries inherit source from their parent.
  final Map<String, (NestedQuery, Source)> _pendingNestedCallbacks = {};

  /// For RemoteSource: tracks IDs that arrived via our subscription.
  /// Only these IDs are emitted (excludes pre-existing local data).
  final Set<String> _arrivedViaSubscription = {};

  /// The parent subscription ID, used for relationship queries
  late final String _parentSubscriptionId;

  /// Timer for responseTimeout enforcement
  Timer? _responseTimeoutTimer;

  /// Whether EOSE has been received for the primary query.
  /// Used to keep StorageLoading until initial load completes for LocalAndRemoteSource.
  bool _eoseReceived = false;

  /// Guard: prevent concurrent refreshes
  bool _isRefreshing = false;

  /// Guard: prevent re-entrant relationship processing
  bool _isProcessingRelationships = false;

  RequestNotifier(this.ref, this.req, Source? source)
    : storage = ref.read(storageNotifierProvider.notifier),
      source =
          source ??
          ref.read(storageNotifierProvider.notifier).config.defaultQuerySource,
      super(StorageLoading([])) {
    if (req.filters.isEmpty) return;

    _parentSubscriptionId = req.subscriptionId;

    _startSubscription();
    _startResponseTimeout();
    _initialize();

    ref.onDispose(() async {
      _responseTimeoutTimer?.cancel();
      await storage.cancel(req);
      await Future.wait(_relationshipRequests.map((r) => storage.cancel(r)));
      // Clean up tracking structures
      _processedModelEventIds.clear();
      _streamingRequestToPrefixed.clear();
      _pendingNestedCallbacks.clear();
      _arrivedViaSubscription.clear();
    });
  }

  /// Start the response timeout timer.
  void _startResponseTimeout() {
    if (source is! RemoteSource) return;

    _responseTimeoutTimer = Timer(storage.config.responseTimeout, () {
      if (!mounted) return;
      if (state is StorageLoading) {
        _eoseReceived = true;
        state = StorageData(state.models);
      }
    });
  }

  /// Initialize the query based on source type.
  Future<void> _initialize() async {
    try {
      switch (source) {
        case LocalSource():
          final models = await storage.query(req, source: LocalSource());
          _emit(models);

        case final LocalAndRemoteSource remoteSource:
          final local = await storage.query(req, source: LocalSource());
          if (local.isNotEmpty) _emit(local);

          if (remoteSource.cachedFor != null &&
              storage.isCacheValid(req, remoteSource.cachedFor!)) {
            // Cache is valid, just emit local data (even if empty)
            _eoseReceived = true;
            if (local.isEmpty && state is StorageLoading) {
              _emit([]);
            } else {
              _emit(local);
            }
            return;
          }

          // Fire remote query (side-effectful).
          // Updates arrive via InternalStorageData notifications.
          await _fireRemoteQuery(req, remoteSource);

          // EOSE received - now we can emit StorageData
          _eoseReceived = true;

          // Update cache timestamp after remote query completes
          if (remoteSource.cachedFor != null) {
            storage.updateCacheTimestamp(req);
          }

          // Final refresh now emits StorageData
          if (mounted) {
            await _refreshFromLocal();
          }

        case final RemoteSource remoteSource:
          // Fire remote query and use returned models directly.
          // For stream: false, InternalStorageData notifications aren't sent,
          // so we must use the models returned from the query.
          final models = await _fireRemoteQuery(req, remoteSource);
          if (mounted) {
            final typedModels = models.whereType<E>().toList();
            if (typedModels.isNotEmpty) {
              // Track arrived IDs for consistency with streaming behavior
              _arrivedViaSubscription.addAll(typedModels.map((m) => m.id));
              _emitIncremental(typedModels);
            } else if (state is StorageLoading) {
              _emit([]);
            }
          }
      }
    } catch (e, stack) {
      if (mounted) {
        state = StorageError(state.models, exception: e, stackTrace: stack);
      }
    }
  }

  /// Fire a remote query and return the models.
  ///
  /// For non-buffered queries (RemoteSource, streaming LocalAndRemoteSource),
  /// returns the actual models from the query. For buffered queries
  /// (LocalAndRemoteSource non-streaming), returns empty list since those
  /// notifiers refresh from local storage via InternalStorageData.
  Future<List<Model<dynamic>>> _fireRemoteQuery(
    Request request,
    RemoteSource source,
  ) {
    final subId = request.subscriptionId;
    final lastDash = subId.lastIndexOf('-');
    final prefix = lastDash > 0 ? subId.substring(0, lastDash) : null;
    return _getQueryBuffer(storage).bufferQuery(request, source, prefix);
  }

  /// Check if an incoming subscription ID matches our subscription prefix.
  /// Used for RemoteSource where the buffer/storage may generate a different
  /// subscription ID suffix while preserving the prefix.
  bool _matchesByPrefix(String? incomingSubId) {
    if (incomingSubId == null) return false;

    final ourSubId = req.subscriptionId;
    final ourLastDash = ourSubId.lastIndexOf('-');
    if (ourLastDash <= 0) {
      // No dash in our ID, fall back to exact match
      return incomingSubId == ourSubId;
    }

    final ourPrefix = ourSubId.substring(0, ourLastDash);
    // Check if incoming ID starts with our prefix followed by a dash
    return incomingSubId.startsWith('$ourPrefix-');
  }

  /// Listen for storage updates and refresh models accordingly.
  void _startSubscription() {
    final sub = ref.listen(storageNotifierProvider, (_, storageState) async {
      if (!mounted) return;
      if (storageState is! InternalStorageData) return;

      final isOurSubscription =
          storageState.req?.subscriptionId == req.subscriptionId;
      final isGeneralUpdate = storageState.req == null;

      // For non-RemoteSource, skip empty updates
      // For RemoteSource, empty updates signal "query completed with no results"
      if (storageState.updatedIds.isEmpty && source is! RemoteSource) return;
      if (storageState.updatedIds.isEmpty && !isOurSubscription) return;

      // Check if this is a relationship update and process nested callbacks
      final relSubId = storageState.req?.subscriptionId;
      if (relSubId != null && _pendingNestedCallbacks.containsKey(relSubId)) {
        await _processNestedCallbacksForUpdate(
          relSubId,
          storageState.updatedIds,
        );
      }

      switch (source) {
        // LocalAndRemoteSource must come before RemoteSource (it's a subclass)
        case LocalSource() || LocalAndRemoteSource():
          // Refresh from local on our subscription or general updates
          if (isOurSubscription || isGeneralUpdate) {
            await _refreshFromLocal();
          } else if (state is! StorageLoading) {
            // Check if update affects our models or relationships
            if (_isRelationshipUpdate(storageState.req) ||
                _affectsOurModels(storageState.updatedIds)) {
              await _refreshFromLocal();
            }
          }

        case RemoteSource():
          // RemoteSource: check by prefix since the buffer/storage may generate
          // a different subscription ID suffix while preserving the prefix.
          // This happens because _fireRemoteQuery extracts the prefix and the
          // buffer/storage may create a new subscription ID with that prefix.
          if (!_matchesByPrefix(storageState.req?.subscriptionId)) return;
          // Track arrived IDs
          _arrivedViaSubscription.addAll(storageState.updatedIds);
          // Fetch arrived models, or transition to empty data if none arrived
          if (_arrivedViaSubscription.isEmpty) {
            // Query completed with no results - transition to empty data
            if (state is StorageLoading) {
              _emit([]);
            }
          } else {
            await _fetchArrivedModels();
          }
      }
    });

    ref.onDispose(() => sub.close());
  }

  /// Process nested `and` callbacks when relationship data arrives via subscription.
  Future<void> _processNestedCallbacksForUpdate(
    String subscriptionId,
    Set<String> updatedIds,
  ) async {
    final entry = _pendingNestedCallbacks[subscriptionId];
    if (entry == null) return;
    final (nq, parentSource) = entry;
    if (nq.and == null || nq.request == null) return;

    // Fetch the models that match the relationship request from local storage
    final models = await storage.query(nq.request!, source: LocalSource());

    // Process nested callbacks for each model
    for (final model in models) {
      final nestedQueries = nq.and!(model);
      for (final nestedNq in nestedQueries) {
        // Pass parent's source so deeply nested queries inherit from parent
        _executeNestedQuery(nestedNq, parentResolvedSource: parentSource);
      }
    }
  }

  /// Check if any of the updated IDs affect models we're tracking.
  bool _affectsOurModels(Set<String> updatedIds) {
    final ourIds = state.models.map((m) => m.id).toSet();
    final ourEventIds = state.models.map((m) => m.event.id).toSet();
    return updatedIds.any(
      (id) => ourIds.contains(id) || ourEventIds.contains(id),
    );
  }

  /// Check if update is from one of our relationship subscriptions.
  bool _isRelationshipUpdate(Request? updateReq) {
    if (updateReq == null) return false;
    return _relationshipRequests.any(
      (r) => r.subscriptionId == updateReq.subscriptionId,
    );
  }

  /// Emit models and process relationships for new/updated models.
  void _emit(List<E> models) {
    _processNewRelationships(models);
    if (!mounted) return;
    // Cancel timeout timer since we're transitioning to data state
    _responseTimeoutTimer?.cancel();

    final sorted = models.toSet().sortByCreatedAt();

    // Stay in StorageLoading until EOSE for LocalAndRemoteSource
    if (source is LocalAndRemoteSource && !_eoseReceived) {
      state = StorageLoading(sorted);
    } else {
      state = StorageData(sorted);
    }
  }

  /// Refresh all matching models from local storage.
  Future<void> _refreshFromLocal() async {
    // Guard against concurrent refreshes
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final models = await storage.query(req, source: LocalSource());
      _emit(models);
    } catch (e, stack) {
      if (mounted) {
        state = StorageError(state.models, exception: e, stackTrace: stack);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// Fetch models that arrived via our subscription (for RemoteSource).
  /// Only emits models whose IDs are in _arrivedViaSubscription.
  Future<void> _fetchArrivedModels() async {
    if (_arrivedViaSubscription.isEmpty) return;

    // Guard against concurrent refreshes
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      // Use Request.fromIds which properly handles both regular event IDs
      // and addressable IDs (kind:pubkey:d-tag format for replaceables).
      // This avoids the bug where copyWith(ids: addressableIds) creates
      // an AND filter that can't match (e.g., kinds:[0] AND ids:["0:abc:"]).
      final idRequest = Request<E>.fromIds(_arrivedViaSubscription);
      final models = await storage.query(idRequest, source: LocalSource());

      _emitIncremental(models);
    } catch (e, stack) {
      if (mounted) {
        state = StorageError(state.models, exception: e, stackTrace: stack);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// Emit new models incrementally, merging with existing state.
  /// Used for RemoteSource where we accumulate models from the subscription.
  void _emitIncremental(List<E> newModels) {
    _processNewRelationships(newModels);
    if (!mounted) return;

    // Merge: new models replace existing ones with same ID
    final existing = {for (final m in state.models) m.id: m};
    for (final m in newModels) {
      existing[m.id] = m;
    }

    // Cancel timeout timer since we're transitioning to data state
    _responseTimeoutTimer?.cancel();
    state = StorageData(existing.values.toSet().sortByCreatedAt());
  }

  /// Process and query relationships for the given models.
  ///
  /// Only processes nested queries for NEW or UPDATED models (different event.id).
  /// Unchanged models are skipped - their relationships haven't changed.
  ///
  /// Nested queries are collected and deduplicated before issuing:
  /// - Streaming: skip if already streaming (by Request equality)
  /// - Non-streaming: go through buffer for merging
  void _processNewRelationships(Iterable<Model<dynamic>> models) {
    // Guard against re-entrant processing
    if (_isProcessingRelationships) return;
    _isProcessingRelationships = true;

    try {
      final andFns = req.filters.map((f) => f.and).nonNulls.toList();
      if (andFns.isEmpty) return;

      // Collect all nested queries from new/updated models
      final nestedQueries = <NestedQuery>[];

      for (final m in models) {
        final previousEventId = _processedModelEventIds[m.id];
        final isNewOrUpdated =
            previousEventId == null || previousEventId != m.event.id;

        // Skip unchanged models - their relationships haven't changed
        if (!isNewOrUpdated) continue;

        _processedModelEventIds[m.id] = m.event.id;

        // Collect nested queries for this model
        for (final andFn in andFns) {
          nestedQueries.addAll(andFn(m));
        }
      }

      // Deduplicate by Request equality before issuing
      final seen = <Request>{};
      for (final nq in nestedQueries) {
        if (nq.request == null) continue;
        if (seen.contains(nq.request)) continue;
        seen.add(nq.request!);
        _executeNestedQuery(nq);
      }
    } finally {
      _isProcessingRelationships = false;
    }
  }

  /// Execute a single nested query with its specific source.
  ///
  /// Called only for new/updated models. Requests are already deduplicated
  /// by the caller, but streaming requests are also tracked to avoid
  /// duplicate subscriptions across flushes.
  ///
  /// [parentResolvedSource] is the resolved source from the parent nested query.
  /// If provided, nested queries without explicit source inherit from parent,
  /// not from the outer query. This enables proper inheritance chains like:
  /// outer(stream:true) -> nested(stream:false) -> nested-of-nested(inherits stream:false)
  void _executeNestedQuery(NestedQuery nq, {Source? parentResolvedSource}) {
    final request = nq.request;
    if (request == null || request.filters.isEmpty) return;

    // Resolve source: explicit > parent > outer
    final nestedSource = nq.source ?? parentResolvedSource ?? source;

    // Only execute remote queries
    if (nestedSource is! RemoteSource) return;

    final isStreaming = nestedSource.stream;

    // For streaming: if already streaming this request, close old subscription
    // (model must have updated for us to reach here)
    final existingPrefixed = _streamingRequestToPrefixed[request];
    if (existingPrefixed != null && isStreaming) {
      storage.cancel(existingPrefixed);
      _relationshipRequests.remove(existingPrefixed);
      _streamingRequestToPrefixed.remove(request);
      _pendingNestedCallbacks.remove(existingPrefixed.subscriptionId);
    }

    // Resolve subscription prefix
    final prefix = nq.subscriptionPrefix ?? '$_parentSubscriptionId--rel';
    final prefixedRequest = request.filters.toRequest(
      subscriptionPrefix: prefix,
    );

    // Track for cancellation and testing
    _relationshipRequests.add(prefixedRequest);
    _totalRelationshipQueriesIssued++;

    // Track streaming requests
    if (isStreaming) {
      _streamingRequestToPrefixed[request] = prefixedRequest;
    }

    // Track nested queries with `and` callbacks for subscription-based updates
    // Store both the query and resolved source for proper inheritance
    if (nq.and != null) {
      _pendingNestedCallbacks[prefixedRequest.subscriptionId] = (
        nq,
        nestedSource,
      );
    }

    // Fire query (side-effectful)
    _fireRemoteQuery(prefixedRequest, nestedSource)
        .then((_) {
          // For non-streaming, clean up after completion
          if (!isStreaming) {
            _pendingNestedCallbacks.remove(prefixedRequest.subscriptionId);
          }

          // Process nested `and` callbacks if present
          if (nq.and != null) {
            _processNestedAndCallbacks(nq, prefixedRequest, nestedSource);
          }

          // For non-streaming LocalAndRemoteSource, refresh after EOSE
          if (mounted && !isStreaming && nestedSource is LocalAndRemoteSource) {
            _refreshFromLocal();
          }
        })
        .catchError((e, stack) {
          // Clean up on error
          _pendingNestedCallbacks.remove(prefixedRequest.subscriptionId);
          if (isStreaming) {
            _streamingRequestToPrefixed.remove(request);
          }

          if (mounted) {
            state = StorageError(state.models, exception: e, stackTrace: stack);
          }
        });
  }

  /// Process nested `and` callbacks after a relationship query completes.
  ///
  /// [parentResolvedSource] is the resolved source of the parent nested query,
  /// used for source inheritance by nested-of-nested queries.
  Future<void> _processNestedAndCallbacks(
    NestedQuery nq,
    Request prefixedRequest,
    Source parentResolvedSource,
  ) async {
    if (nq.and == null || nq.request == null) return;

    // Fetch relationship models from local storage
    final models = await storage.query(nq.request!, source: LocalSource());

    for (final model in models) {
      final nestedQueries = nq.and!(model);
      for (final nestedNq in nestedQueries) {
        // Pass parent's source so deeply nested queries inherit from parent, not outer
        _executeNestedQuery(
          nestedNq,
          parentResolvedSource: parentResolvedSource,
        );
      }
    }
  }
}

final Map<
  _ProviderCacheKey,
  AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>
>
_typedProviderCache = {};

/// Cache key that includes filter, source, and subscription prefix.
class _ProviderCacheKey {
  final RequestFilter filter;
  final Source? source;
  final String? subscriptionPrefix;

  _ProviderCacheKey(this.filter, this.source, this.subscriptionPrefix);

  @override
  bool operator ==(Object other) =>
      other is _ProviderCacheKey &&
      other.filter == filter &&
      other.source == source &&
      other.subscriptionPrefix == subscriptionPrefix;

  @override
  int get hashCode => Object.hash(filter, source, subscriptionPrefix);
}

/// Family of notifier providers, one per request.
/// Manually caching since a factory function is needed to pass the type.
_requestNotifierProvider<E extends Model<dynamic>>(
  RequestFilter<E> filter,
  Source? source,
  String? subscriptionPrefix,
) {
  final cacheKey = _ProviderCacheKey(filter, source, subscriptionPrefix);
  return _typedProviderCache[cacheKey] ??= StateNotifierProvider.autoDispose
      .family<RequestNotifier<E>, StorageState<E>, RequestFilter<E>>((
        ref,
        req,
      ) {
        ref.onDispose(() => _typedProviderCache.remove(cacheKey));
        return RequestNotifier(
          ref,
          filter.toRequest(subscriptionPrefix: subscriptionPrefix),
          source,
        );
      })(filter);
}

/// Query for models of any kind.
///
/// If [source] is not provided, uses [StorageConfiguration.defaultQuerySource].
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState> queryKinds({
  Set<String>? ids,
  Set<int>? kinds,
  Set<String>? authors,
  Map<String, Set<String>>? tags,
  String? search,
  DateTime? since,
  DateTime? until,
  int? limit,
  Source? source,
  String? subscriptionPrefix,
  AndFunction and,
  WhereFunction where,
  SchemaFilter? schemaFilter,
}) {
  final filter = RequestFilter(
    ids: ids,
    kinds: kinds,
    authors: authors,
    tags: tags,
    search: search,
    since: since,
    until: until,
    limit: limit,
    where: where,
    and: and,
    schemaFilter: schemaFilter,
  );
  return _requestNotifierProvider(filter, source, subscriptionPrefix);
}

/// Query for models of a specific type [E].
///
/// If [source] is not provided, uses [StorageConfiguration.defaultQuerySource].
AutoDisposeStateNotifierProvider<RequestNotifier<E>, StorageState<E>>
query<E extends Model<E>>({
  Set<String>? ids,
  Set<String>? authors,
  Map<String, Set<String>>? tags,
  String? search,
  DateTime? since,
  DateTime? until,
  int? limit,
  Source? source,
  String? subscriptionPrefix,
  WhereFunction<E> where,
  AndFunction<E> and,
  SchemaFilter? schemaFilter,
}) {
  final filter = RequestFilter<E>(
    ids: ids,
    authors: authors,
    tags: tags,
    search: search,
    since: since,
    until: until,
    limit: limit,
    where: _castWhere(where),
    and: _castAnd(and),
    schemaFilter: schemaFilter,
  );
  return _requestNotifierProvider<E>(filter, source, subscriptionPrefix);
}

/// Watch a specific model instance.
///
/// If [source] is not provided, uses [StorageConfiguration.defaultQuerySource].
AutoDisposeStateNotifierProvider<RequestNotifier<E>, StorageState<E>> model<
  E extends Model<E>
>(E model, {Source? source, String? subscriptionPrefix, AndFunction<E> and}) {
  final filter = RequestFilter<E>(ids: {model.id}, and: _castAnd(and));
  return _requestNotifierProvider<E>(filter, source, subscriptionPrefix);
}

typedef AndFunction<E extends Model<dynamic>> = Set<NestedQuery> Function(E)?;

typedef WhereFunction<E extends Model<dynamic>> = bool Function(E)?;

AndFunction _castAnd<E extends Model<E>>(AndFunction<E> andFn) {
  return andFn == null ? null : (e) => andFn(e as E);
}

WhereFunction _castWhere<E extends Model<E>>(WhereFunction<E> whereFn) {
  return whereFn == null ? null : (e) => whereFn(e as E);
}

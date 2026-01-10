part of models;

/// Global buffer for batching remote queries across all RequestNotifier instances.
///
/// When multiple queries arrive within [StorageConfiguration.requestBufferDuration],
/// they are collected, merged into fewer relay requests, and sent together.
/// This prevents N+1 query problems when many providers are created simultaneously.
class _RemoteQueryBuffer {
  final StorageNotifier storage;
  Timer? _timer;

  /// Pending queries grouped by source key (relay target + stream mode).
  /// Each entry contains the requests and their completers.
  final Map<String, List<_PendingQuery>> _pending = {};

  _RemoteQueryBuffer(this.storage);

  /// Buffer a remote query for batched execution.
  ///
  /// Returns a Future that completes when the (merged) query completes.
  /// Streaming queries are not buffered as they rely on subscription IDs
  /// for incremental updates.
  Future<List<Model<dynamic>>> bufferQuery(
    Request request,
    RemoteSource source,
    String? subscriptionPrefix,
  ) {
    // Skip buffering for streaming queries - they need their original
    // subscription IDs for the streaming update mechanism to work
    if (source.stream) {
      return storage.query(request, source: source, subscriptionPrefix: subscriptionPrefix);
    }

    final completer = Completer<List<Model<dynamic>>>();
    final key = _sourceKey(source);

    _pending.putIfAbsent(key, () => []).add(_PendingQuery(
      request: request,
      source: source,
      subscriptionPrefix: subscriptionPrefix,
      completer: completer,
    ));

    // Reset timer on each new request
    _timer?.cancel();

    final bufferDuration = storage.config.requestBufferDuration;
    if (bufferDuration == Duration.zero) {
      // Flush immediately when no buffering is configured (e.g., in tests)
      _flush();
    } else {
      _timer = Timer(bufferDuration, _flush);
    }

    return completer.future;
  }

  /// Create a key for grouping sources that can be merged.
  /// Queries with the same relay target and stream mode can be merged.
  String _sourceKey(RemoteSource source) {
    final relays = source.relays?.toString() ?? 'outbox';
    final stream = source.stream;
    final type = source is LocalAndRemoteSource ? 'local_and_remote' : 'remote';
    return '$type:$relays:$stream';
  }

  /// Flush all pending queries, merging where possible.
  void _flush() {
    if (_pending.isEmpty) return;

    final pendingSnapshot = Map<String, List<_PendingQuery>>.from(_pending);
    _pending.clear();

    for (final entry in pendingSnapshot.entries) {
      final queries = entry.value;
      if (queries.isEmpty) continue;

      // Merge all requests in this group
      final allFilters = queries.expand((q) => q.request.filters).toList();
      final mergedFilters = RequestFilter.mergeMultiple(allFilters);

      // Use the first query's source (they all have same relay/stream config)
      final source = queries.first.source;
      final basePrefix = queries.first.subscriptionPrefix;
      
      // Add merged indicator when multiple queries are combined
      final prefix = queries.length > 1
          ? '$basePrefix--merged${queries.length}'
          : basePrefix;

      // Create merged request
      final mergedRequest = mergedFilters.toRequest(subscriptionPrefix: prefix);

      // Execute merged query
      storage
          .query(mergedRequest, source: source, subscriptionPrefix: prefix)
          .then((models) {
            // Complete all original completers with the merged result
            for (final q in queries) {
              q.completer.complete(models);
            }
          })
          .catchError((e, stack) {
            // Propagate error to all completers
            for (final q in queries) {
              q.completer.completeError(e, stack);
            }
          });
    }
  }

  /// Cancel the buffer timer.
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
  final Source? andSource;
  final StorageNotifier storage;
  final Set<Request> relationshipRequests = {};
  final List<Request> mergedRelationshipRequests = [];

  /// The parent subscription ID, used for relationship queries
  late final String _parentSubscriptionId;

  /// Timer for responseTimeout enforcement
  Timer? _responseTimeoutTimer;

  RequestNotifier(this.ref, this.req, Source? source, [this.andSource])
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
      await Future.wait(
        mergedRelationshipRequests.map((r) => storage.cancel(r)),
      );
    });
  }

  /// Start the response timeout timer.
  void _startResponseTimeout() {
    if (source is! RemoteSource) return;

    _responseTimeoutTimer = Timer(storage.config.responseTimeout, () {
      if (!mounted) return;
      if (state is StorageLoading) {
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
            if (local.isEmpty && state is StorageLoading) {
              _emit([]);
            }
            return;
          }

          // Fire remote query via buffer. Per-EOSE updates arrive via
          // InternalStorageData notifications caught by _startSubscription.
          await _bufferRemoteQuery(req, remoteSource);

          // Update cache timestamp after successful remote query
          if (remoteSource.cachedFor != null) {
            storage.updateCacheTimestamp(req);
          }

          // Final refresh after all EOSEs complete.
          // For streaming: only refresh if still loading (handles empty EOSE)
          if (mounted && (!remoteSource.stream || state is StorageLoading)) {
            await _refreshFromLocal();
          }

        case final RemoteSource remoteSource:
          final models = await _bufferRemoteQuery(req, remoteSource);

          if (mounted) {
            if (models.isNotEmpty) {
              _emitIncremental(models.cast<E>());
            } else if (state is StorageLoading) {
              // After EOSE with no models, transition to empty data
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

  /// Buffer a remote query for batched execution.
  Future<List<Model<dynamic>>> _bufferRemoteQuery(
    Request request,
    RemoteSource source,
  ) {
    // Extract prefix from subscription ID (everything before the last -number)
    final subId = request.subscriptionId;
    final lastDash = subId.lastIndexOf('-');
    final prefix = lastDash > 0 ? subId.substring(0, lastDash) : null;
    return _getQueryBuffer(storage).bufferQuery(request, source, prefix);
  }

  /// Listen for storage updates and refresh models accordingly.
  void _startSubscription() {
    final sub = ref.listen(storageNotifierProvider, (_, storageState) async {
      if (!mounted) return;
      if (storageState is! InternalStorageData) return;
      if (storageState.updatedIds.isEmpty) return;

      final isOurSubscription =
          storageState.req?.subscriptionId == req.subscriptionId;
      final isGeneralUpdate = storageState.req == null;

      switch (source) {
        // LocalAndRemoteSource must come before RemoteSource (it's a subclass)
        case LocalSource() || LocalAndRemoteSource():
          // Refresh from local on our subscription or general updates
          if (isOurSubscription || isGeneralUpdate) {
            await _refreshFromLocal();
          } else if (state is! StorageLoading) {
            // Check if update affects our models or relationships
            final isRelationshipUpdate = mergedRelationshipRequests.any(
              (r) => r.subscriptionId == storageState.req?.subscriptionId,
            );
            if (isRelationshipUpdate ||
                _affectsOurModels(storageState.updatedIds)) {
              await _refreshFromLocal();
            }
          }

        case RemoteSource():
          // RemoteSource only cares about its own subscription
          if (!isOurSubscription) return;
          await _fetchByIds(storageState.updatedIds);
      }
    });

    ref.onDispose(() => sub.close());
  }

  /// Check if any of the updated IDs affect models we're tracking.
  bool _affectsOurModels(Set<String> updatedIds) {
    final ourIds = state.models.map((m) => m.id).toSet();
    final ourEventIds = state.models.map((m) => m.event.id).toSet();
    return updatedIds.any(
      (id) => ourIds.contains(id) || ourEventIds.contains(id),
    );
  }

  /// Emit models and process relationships.
  void _emit(List<E> models) {
    _processNewRelationships(models);
    if (!mounted) return;
    // Cancel timeout timer since we're transitioning to data state
    _responseTimeoutTimer?.cancel();
    state = StorageData(models.toSet().sortByCreatedAt());
  }

  /// Refresh all matching models from local storage.
  Future<void> _refreshFromLocal() async {
    try {
      final models = await storage.query(req, source: LocalSource());
      _emit(models);
    } catch (e, stack) {
      if (mounted) {
        state = StorageError(state.models, exception: e, stackTrace: stack);
      }
    }
  }

  /// Fetch specific models by ID (for RemoteSource).
  /// Maintains remote-only semantics by only returning models that arrived
  /// via our subscription, not pre-existing local data.
  Future<void> _fetchByIds(Set<String> updatedIds) async {
    try {
      final idRequest = Request<E>(
        req.filters.map((f) => f.copyWith(ids: updatedIds)).toList(),
      );
      final models = await storage.query(idRequest, source: LocalSource());
      _emitIncremental(models);
    } catch (e, stack) {
      if (mounted) {
        state = StorageError(state.models, exception: e, stackTrace: stack);
      }
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

  List<Relationship> _getRelationshipsFrom(Iterable<Model<dynamic>> models) {
    final andFns = req.filters.map((f) => f.and).nonNulls;
    return [
      for (final andFn in andFns)
        for (final m in models) ...andFn(m).nonNulls,
    ];
  }

  /// Process and query new relationships for the given models.
  ///
  /// Relationship queries are sent to the global buffer which batches
  /// them with other concurrent queries before sending to relays.
  void _processNewRelationships(Iterable<Model<dynamic>> models) {
    final relationshipSource = andSource ?? source;

    if (relationshipSource is! RemoteSource) {
      return;
    }

    _executeRelationshipQueries(models);
  }

  /// Execute relationship queries for the given models.
  void _executeRelationshipQueries(Iterable<Model<dynamic>> models) {
    final newRelationshipRequests = [
      for (final r in _getRelationshipsFrom(models))
        if (!relationshipRequests.contains(r.req)) r.req,
    ].nonNulls;

    if (newRelationshipRequests.isEmpty) return;

    relationshipRequests.addAll(newRelationshipRequests);

    final mergedRequest = RequestFilter.mergeMultiple(
      newRelationshipRequests.expand((r) => r.filters).toList(),
    ).toRequest(subscriptionPrefix: '$_parentSubscriptionId--rel');

    final relationshipSource = andSource ?? source;

    if (mergedRequest.filters.isNotEmpty &&
        relationshipSource is RemoteSource) {
      mergedRelationshipRequests.add(mergedRequest);

      _bufferRemoteQuery(mergedRequest, relationshipSource)
          .then((_) {
            // For non-streaming, refresh after EOSE
            if (mounted && !relationshipSource.stream) {
              switch (relationshipSource) {
                case LocalAndRemoteSource():
                  _refreshFromLocal();
                case RemoteSource():
                  // Signal completion for pure RemoteSource relationships
                  if (state is StorageLoading) {
                    state = StorageData(state.models);
                  }
              }
            }
          })
          .catchError((e, stack) {
            print('Relationship query error: $e\n$stack');
            if (mounted) _refreshFromLocal();
          });
    }
  }
}

final Map<
  RequestFilter,
  AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>
>
_typedProviderCache = {};

/// Family of notifier providers, one per request.
/// Manually caching since a factory function is needed to pass the type.
_requestNotifierProvider<E extends Model<dynamic>>(
  RequestFilter<E> filter,
  Source? source,
  Source? andSource,
  String? subscriptionPrefix,
) => _typedProviderCache[filter] ??= StateNotifierProvider.autoDispose
    .family<RequestNotifier<E>, StorageState<E>, RequestFilter<E>>((ref, req) {
      ref.onDispose(() => _typedProviderCache.remove(filter));
      return RequestNotifier(
        ref,
        filter.toRequest(subscriptionPrefix: subscriptionPrefix),
        source,
        andSource,
      );
    })(filter);

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
  Source? andSource,
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
  return _requestNotifierProvider(
    filter,
    source,
    andSource,
    subscriptionPrefix,
  );
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
  Source? andSource,
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
  return _requestNotifierProvider<E>(
    filter,
    source,
    andSource,
    subscriptionPrefix,
  );
}

/// Watch a specific model instance.
///
/// If [source] is not provided, uses [StorageConfiguration.defaultQuerySource].
AutoDisposeStateNotifierProvider<RequestNotifier<E>, StorageState<E>>
model<E extends Model<E>>(
  E model, {
  Source? source,
  Source? andSource,
  String? subscriptionPrefix,
  AndFunction<E> and,
  bool remote = true,
}) {
  final filter = RequestFilter<E>(ids: {model.id}, and: _castAnd(and));
  return _requestNotifierProvider<E>(
    filter,
    source,
    andSource,
    subscriptionPrefix,
  );
}

typedef AndFunction<E extends Model<dynamic>> =
    Set<Relationship<Model>?> Function(E)?;

typedef WhereFunction<E extends Model<dynamic>> = bool Function(E)?;

AndFunction _castAnd<E extends Model<E>>(AndFunction<E> andFn) {
  return andFn == null ? null : (e) => andFn(e as E);
}

WhereFunction _castWhere<E extends Model<E>>(WhereFunction<E> whereFn) {
  return whereFn == null ? null : (e) => whereFn(e as E);
}

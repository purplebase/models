part of models;

/// A request notifier takes a [Request]
/// that it uses to query and then filter incoming
/// events from [StorageNotifier]
class RequestNotifier<E extends Model<dynamic>>
    extends StateNotifier<StorageState<E>> {
  final Ref ref;
  final Request<E> req;
  final Source source;
  final Source? andSource;
  final StorageNotifier storage;
  final Set<Request> relationshipRequests = {};
  final List<Request> mergedRelationshipRequests = [];

  RequestNotifier(this.ref, this.req, this.source, [this.andSource])
    : storage = ref.read(storageNotifierProvider.notifier),
      super(StorageLoading([])) {
    if (req.filters.isEmpty) return;

    // Extract prefix from the request's subscriptionId to reuse for internal queries
    final prefix = req.subscriptionId.contains('-')
        ? req.subscriptionId.split('-').first
        : null;

    // Start subscription FIRST to avoid race condition where InternalStorageData
    // arrives before the listener is registered. This ensures we don't miss any
    // updates that happen during the query.
    _startSubscription();

    // For LocalAndRemoteSource: query local storage FIRST and emit immediately,
    // then fire the remote query. This ensures the query provider returns local
    // data immediately regardless of stream setting. The stream parameter only
    // affects whether the remote subscription stays open after EOSE.
    //
    // For RemoteSource or LocalSource: query directly with the source.
    if (source is LocalAndRemoteSource) {
      final isStreaming = (source as LocalAndRemoteSource).stream;

      // Step 1: Query local storage immediately (non-blocking)
      storage
          .query(req, source: LocalSource())
          .then((localModels) {
            // Emit local results immediately if not empty
            // If empty, stay in StorageLoading to avoid empty flash
            if (localModels.isNotEmpty) {
              _emitNewModels(localModels);
            }

            // Step 2: Fire remote query (may block for stream: false, but that's fine
            // since we've already emitted local data)
            return storage.query(
              req,
              source: source,
              subscriptionPrefix: prefix,
            );
          })
          .then((remoteModels) {
            // Remote query completed
            // For stream: false (one-time fetch), refresh to pick up any new data
            // For stream: true, the subscription handles updates via InternalStorageData
            if (mounted && !isStreaming) {
              _refreshModels();
            }
          })
          .catchError((e, stack) {
            if (mounted) {
              state = StorageError(
                state.models,
                exception: e,
                stackTrace: stack,
              );
            } else {
              print(e);
            }
          });
    } else {
      // LocalSource or RemoteSource: query directly
      storage
          .query(req, source: source, subscriptionPrefix: prefix)
          .then((models) {
            _emitNewModels(models);
          })
          .catchError((e, stack) {
            if (mounted) {
              state = StorageError(
                state.models,
                exception: e,
                stackTrace: stack,
              );
            } else {
              print(e);
            }
          });
    }

    ref.onDispose(() async {
      // Cancel main request
      await storage.cancel(req);

      // Cancel all merged relationship requests (the actual subscriptions)
      await Future.wait(
        mergedRelationshipRequests.map(
          (mergedReq) => storage.cancel(mergedReq),
        ),
      );
    });
  }

  /// Whether this source includes local storage data.
  /// LocalSource and LocalAndRemoteSource include local; RemoteSource does not.
  bool get _sourceIncludesLocal =>
      source is LocalSource || source is LocalAndRemoteSource;

  void _startSubscription() {
    final sub = ref.listen(storageNotifierProvider, (_, storageState) async {
      if (!mounted) return;

      if (storageState case InternalStorageData(
        req: final incomingReq,
        :final updatedIds,
      ) when updatedIds.isNotEmpty) {
        // Check if this update is from our specific subscription
        final isOurSubscription =
            incomingReq?.subscriptionId == req.subscriptionId;

        // General updates (incomingReq == null) only matter for sources that
        // include local storage. For RemoteSource, we only care about updates
        // from our specific remote subscription.
        final isGeneralUpdate = incomingReq == null;

        if (isOurSubscription || (isGeneralUpdate && _sourceIncludesLocal)) {
          await _refreshModels();
        } else {
          // Ignore unrelated updates while still in initial loading state
          // This prevents wrongly transitioning from Loading to empty Data
          // Once we've transitioned to StorageData (even if empty), process normally
          if (state is StorageLoading) return;

          // For RemoteSource, skip processing unrelated updates entirely
          // since we only care about data from our remote subscription
          if (!_sourceIncludesLocal) return;

          // Check if any updatedIds affect our models (for replaceable updates)
          // Pre-compute both Sets for O(1) lookups instead of O(n) scans
          final ourIds = state.models.map((m) => m.id).toSet();
          final ourEventIds = state.models.map((m) => m.event.id).toSet();
          final hasRelevantUpdate = updatedIds.any(
            (id) => ourIds.contains(id) || ourEventIds.contains(id),
          );

          if (hasRelevantUpdate) {
            // Replaceable model was updated - refresh from storage
            await _refreshModels();
          } else {
            // Check if this update is from one of our relationship requests
            // If so, refresh models to pick up the new relationship data
            // and re-evaluate the and: callback for nested relationships
            final isRelationshipUpdate = mergedRelationshipRequests.any(
              (r) => r.subscriptionId == incomingReq?.subscriptionId,
            );

            if (isRelationshipUpdate) {
              // Relationship data arrived - refresh models from local storage
              // This ensures nested relationships are properly discovered
              await _refreshModels();
            } else {
              // Truly unrelated update - just process any new relationships
              _processNewRelationships(state.models);
              state = StorageData(state.models);
            }
          }
        }
      }
    });

    ref.onDispose(() => sub.close());
  }

  List<Relationship> _getRelationshipsFrom(Iterable<Model<dynamic>> models) {
    final andFns = req.filters.map((f) => f.and).nonNulls;
    return [
      for (final andFn in andFns)
        for (final m in models) ...andFn(m).nonNulls,
    ];
  }

  /// Process and query new relationships for the given models
  void _processNewRelationships(Iterable<Model<dynamic>> models) {
    // Calculate new relationships from models
    final newRelationshipRequests = [
      for (final r in _getRelationshipsFrom(models))
        if (!relationshipRequests.contains(r.req)) r.req,
    ].nonNulls;

    if (newRelationshipRequests.isEmpty) return;

    relationshipRequests.addAll(newRelationshipRequests);

    // Extract prefix from the main request to use for relationships
    final prefix = req.subscriptionId.contains('-')
        ? req.subscriptionId.split('-').first
        : null;

    final mergedRelationshipRequest = RequestFilter.mergeMultiple(
      newRelationshipRequests.expand((r) => r.filters).toList(),
    ).toRequest(subscriptionPrefix: prefix);

    // Determine the source to use for relationship queries
    // Use custom andSource if provided, otherwise use the parent source
    final relationshipSource = andSource ?? source;

    // Only query if we have filters and a remote source to query
    if (mergedRelationshipRequest.filters.isNotEmpty &&
        relationshipSource is RemoteSource) {
      // Store the merged request for proper cleanup on dispose
      mergedRelationshipRequests.add(mergedRelationshipRequest);

      final isStreaming = relationshipSource.stream;

      // Fire the relationship query
      final queryFuture = storage.query(
        mergedRelationshipRequest,
        source: relationshipSource,
        subscriptionPrefix: prefix,
      );

      // For non-streaming queries (stream: false), we must explicitly refresh
      // after the query completes because there's no subscription to push updates.
      // For streaming queries, updates arrive via InternalStorageData callbacks.
      if (!isStreaming) {
        queryFuture.then((_) {
          if (mounted) {
            _refreshModels();
          }
        });
      }
    }
  }

  /// Refresh models from storage using the appropriate source.
  /// For sources that include local (LocalSource, LocalAndRemoteSource),
  /// queries local storage. For RemoteSource, queries with the original source
  /// to maintain remote-only semantics.
  Future<void> _refreshModels() async {
    try {
      // Use LocalSource for refresh when the original source includes local,
      // otherwise use the original source to maintain remote-only semantics
      final refreshSource = _sourceIncludesLocal ? LocalSource() : source;
      final refreshedModels = await storage.query(req, source: refreshSource);
      _replaceAllModels(refreshedModels);
    } catch (e, stack) {
      state = StorageError(state.models, exception: e, stackTrace: stack);
    }
  }

  void _replaceAllModels(Iterable<Model<dynamic>> models) {
    final typedModels = models.whereType<E>();

    _processNewRelationships(typedModels);

    if (!mounted) return;

    final sortedModels = typedModels.toSet().sortByCreatedAt();
    state = StorageData(sortedModels);
  }

  void _emitNewModels(Iterable<Model<dynamic>> models) {
    // Filter only models of type E
    // Related models are stored in request cache, they only
    // thing to do is trigger a rebuild
    final newModels = models.whereType<E>();

    // Process relationships for newly arrived models
    _processNewRelationships(newModels);

    if (!mounted) return;

    // Handle duplicates: remove existing models that are being replaced by new models
    final existingModels = state.models.toList();
    final modelsToKeep = <E>[];

    for (final existingModel in existingModels) {
      // Check if any new model replaces this existing model
      final hasReplacement = newModels.any((newModel) {
        // For replaceable models, check addressable ID
        if (newModel is ReplaceableModel && existingModel is ReplaceableModel) {
          return newModel.id == existingModel.id;
        }
        // For regular models, check event ID to avoid duplicates
        return newModel.event.id == existingModel.event.id;
      });

      if (!hasReplacement) {
        modelsToKeep.add(existingModel);
      }
    }

    // Combine kept models with new models and sort
    // Put them in a Set to remove duplicates, new models take precedence
    final sortedModels = {...newModels, ...modelsToKeep}.sortByCreatedAt();

    if (mounted) {
      state = StorageData(sortedModels);
    }
  }
}

final Map<
  RequestFilter,
  AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>
>
_typedProviderCache = {};

/// Family of notifier providers, one per request
/// Manually caching since a factory function is needed to pass the type
_requestNotifierProvider<E extends Model<dynamic>>(
  RequestFilter<E> filter,
  Source source,
  Source? andSource,
  String? subscriptionPrefix,
) => _typedProviderCache[filter] ??= StateNotifierProvider.autoDispose
    .family<RequestNotifier<E>, StorageState<E>, RequestFilter<E>>((ref, req) {
      // Defer Request creation til this point so we leverage
      // equality on the RequestFilter at the provider level

      // Clean up cache entry when provider is disposed
      ref.onDispose(() => _typedProviderCache.remove(filter));
      return RequestNotifier(
        ref,
        filter.toRequest(subscriptionPrefix: subscriptionPrefix),
        source,
        andSource,
      );
    })(filter);

/// Syntax-sugar for `requestNotifierProvider(RequestFilter(...))`
/// with type [Model] (of any kind)
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState> queryKinds({
  Set<String>? ids,
  Set<int>? kinds,
  Set<String>? authors,
  Map<String, Set<String>>? tags,
  String? search,
  DateTime? since,
  DateTime? until,
  int? limit,
  Source source = const LocalAndRemoteSource(),
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

/// Syntax-sugar for `requestNotifierProvider(RequestFilter<E>(...))`
/// with type [E] (one specific kind)
AutoDisposeStateNotifierProvider<RequestNotifier<E>, StorageState<E>>
query<E extends Model<E>>({
  Set<String>? ids,
  Set<String>? authors,
  Map<String, Set<String>>? tags,
  String? search,
  DateTime? since,
  DateTime? until,
  int? limit,
  Source source = const LocalAndRemoteSource(),
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

/// Syntax sugar for watching one model of type [E]
AutoDisposeStateNotifierProvider<RequestNotifier<E>, StorageState<E>>
model<E extends Model<E>>(
  E model, {
  Source source = const LocalAndRemoteSource(),
  Source? andSource,
  String? subscriptionPrefix,
  AndFunction<E> and,
  bool remote = true,
}) {
  // Note: does not need kind or other arguments as it queries by ID
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

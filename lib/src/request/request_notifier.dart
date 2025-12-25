part of models;

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

  /// Subscription prefix extracted from the request's subscriptionId
  late final String? _prefix;

  RequestNotifier(this.ref, this.req, this.source, [this.andSource])
    : storage = ref.read(storageNotifierProvider.notifier),
      super(StorageLoading([])) {
    if (req.filters.isEmpty) return;

    _prefix =
        req.subscriptionId.contains('-')
            ? req.subscriptionId.split('-').first
            : null;

    _startSubscription();
    _initialize();

    ref.onDispose(() async {
      await storage.cancel(req);
      await Future.wait(
        mergedRelationshipRequests.map((r) => storage.cancel(r)),
      );
    });
  }

  /// Initialize the query based on source type.
  Future<void> _initialize() async {
    try {
      switch (source) {
        case LocalSource():
          // SPEC: "emit immediately, even if empty"
          final models = await storage.query(req, source: LocalSource());
          _emit(models);

        case LocalAndRemoteSource(:final stream):
          // SPEC: "emit local models immediately if non-empty"
          final local = await storage.query(req, source: LocalSource());
          if (local.isNotEmpty) _emit(local);

          // Fire remote query. Per-EOSE updates arrive via InternalStorageData
          // notifications caught by _startSubscription (registered before this).
          // This await just waits for all subscriptions to complete.
          await storage.query(req, source: source, subscriptionPrefix: _prefix);

          // Final refresh after all EOSEs complete.
          // For streaming: only refresh if still loading (handles empty EOSE)
          if (mounted && (!stream || state is StorageLoading)) {
            await _refreshFromLocal();
          }

        case RemoteSource():
          // SPEC: "emit exactly the models that came in via those subscriptions"
          // For non-streaming: models come back from query directly
          // For streaming: models arrive via subscription callbacks
          final models = await storage.query(
            req,
            source: source,
            subscriptionPrefix: _prefix,
          );

          if (mounted) {
            if (models.isNotEmpty) {
              _emitIncremental(models);
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
            if (isRelationshipUpdate || _affectsOurModels(storageState.updatedIds)) {
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
    return updatedIds.any((id) => ourIds.contains(id) || ourEventIds.contains(id));
  }

  /// Emit models and process relationships.
  void _emit(List<E> models) {
    _processNewRelationships(models);
    if (!mounted) return;
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
  void _processNewRelationships(Iterable<Model<dynamic>> models) {
    final newRelationshipRequests = [
      for (final r in _getRelationshipsFrom(models))
        if (!relationshipRequests.contains(r.req)) r.req,
    ].nonNulls;

    if (newRelationshipRequests.isEmpty) return;

    relationshipRequests.addAll(newRelationshipRequests);

    final mergedRequest = RequestFilter.mergeMultiple(
      newRelationshipRequests.expand((r) => r.filters).toList(),
    ).toRequest(subscriptionPrefix: _prefix);

    final relationshipSource = andSource ?? source;

    if (mergedRequest.filters.isNotEmpty && relationshipSource is RemoteSource) {
      mergedRelationshipRequests.add(mergedRequest);

      storage
          .query(mergedRequest, source: relationshipSource, subscriptionPrefix: _prefix)
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
  Source source,
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
  return _requestNotifierProvider(filter, source, andSource, subscriptionPrefix);
}

/// Query for models of a specific type [E].
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
  return _requestNotifierProvider<E>(filter, source, andSource, subscriptionPrefix);
}

/// Watch a specific model instance.
AutoDisposeStateNotifierProvider<RequestNotifier<E>, StorageState<E>>
model<E extends Model<E>>(
  E model, {
  Source source = const LocalAndRemoteSource(),
  Source? andSource,
  String? subscriptionPrefix,
  AndFunction<E> and,
  bool remote = true,
}) {
  final filter = RequestFilter<E>(ids: {model.id}, and: _castAnd(and));
  return _requestNotifierProvider<E>(filter, source, andSource, subscriptionPrefix);
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

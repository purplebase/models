part of models;

/// A request notifier takes a [RequestFilter]
/// that it uses to query and then filter incoming
/// events from [StorageNotifier]
class RequestNotifier<E extends Model<dynamic>>
    extends StateNotifier<StorageState<E>> {
  final Ref ref;
  final RequestFilter<E> req;
  final StorageNotifier storage;
  var applyLimit = true;

  RequestNotifier(this.ref, this.req)
      : storage = ref.read(storageNotifierProvider.notifier),
        super(StorageLoading([])) {
    // If no filters were provided, do nothing
    if (req.toMap().isEmpty) {
      return;
    }

    // Trigger initial fetch/query
    fetchAndQuery(req).then((models) {
      if (mounted) {
        state = StorageData(models);
      }
    });

    // Listen for storage which constantly emits updated IDs,
    // and query it back with the current req
    final sub = ref.listen(storageNotifierProvider, (_, incomingIds) async {
      if (!mounted) return;

      if (incomingIds != null && incomingIds.isNotEmpty) {
        // Incoming are the IDs of *any* new models in local storage,
        // so restrict req to them and check if they apply
        // Since only local storage should be checked pass `remote=false`,
        // use `fetchAndQuery` as it will also check for watched relationships
        final updatedReq = req.copyWith(ids: incomingIds, remote: false);
        final updatedModels = await fetchAndQuery(updatedReq);

        if (updatedModels.isNotEmpty) {
          // Replaceable events maintain their IDs across updates
          // so make sure we remove any of these from the current state
          // (otherwise they would be ignored when added to the Set)
          final updatedIds = updatedModels.map((m) => m.id);
          state.models.removeWhere((m) => updatedIds.contains(m.id));

          // Concat and sort
          final sortedModels =
              {...state.models, ...updatedModels}.sortByCreatedAt();
          if (mounted) {
            state = StorageData(sortedModels);
          }
        }
      }
    });

    // Clear cache related to this nostr sub when disposing the notifier
    ref.onDispose(() => storage.requestCache.remove(req.subscriptionId));
    // Close subscription to storage notifier
    ref.onDispose(() => sub.close());
    // Cancel active req subscriptions to relays
    ref.onDispose(() => storage.cancel(req));
  }

  // Fetch models from local storage and send request to relays
  Future<List<E>> fetchAndQuery(RequestFilter<E> req) async {
    // Send req to relays in the background (pre-EOSE + streaming)
    // May be a no-op if `remote=false`
    storage.fetch(req);

    // Since a remote query was just performed, ensure storage.query
    // is local via `remote=false`
    final models = await storage.query(req.copyWith(remote: false));

    // If relationship watchers were provided, find reqs and merge,
    // then query local storage for
    if (req.and != null) {
      final reqs = {
        for (final m in models) ...req.and!(m).map((r) => r.req).nonNulls
      };
      final mergedReqs = mergeMultipleRequests(reqs.toList());

      for (final r in mergedReqs) {
        // Fill the cache to prepare it for sync relationships.
        // Query without hitting relays, we do that below
        // (does not pass E type argument, as these are of any kind)
        final relatedModels = await storage.query(r.copyWith(remote: false));
        storage.requestCache[r.subscriptionId] ??= {};
        storage.requestCache[r.subscriptionId]![r] = relatedModels.cast();

        // Send request filters to relays
        // TODO: Fetch may get new models that expire cache entries, is this covered?
        // Remote should be the exact same as the original req
        storage.fetch(r.copyWith(remote: req.remote));
      }
    }
    return models;
  }
}

final Map<RequestFilter,
        AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>>
    _typedProviderCache = {};

/// Family of notifier providers, one per request
/// Manually caching since a factory function is needed to pass the type
_requestNotifierProvider<E extends Model<dynamic>>(RequestFilter<E> req) =>
    _typedProviderCache[req] ??= StateNotifierProvider.autoDispose
        .family<RequestNotifier<E>, StorageState<E>, RequestFilter<E>>(
      (ref, req) {
        ref.onDispose(() => print('disposing provider'));
        return RequestNotifier(ref, req);
      },
    )(req);

/// Syntax-sugar for `requestNotifierProvider(RequestFilter(...))`
/// with default type ([Model]), [remote] is true by default
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState> queryKinds({
  Set<String>? ids,
  Set<int>? kinds,
  Set<String>? authors,
  Map<String, Set<String>>? tags,
  String? search,
  DateTime? since,
  DateTime? until,
  int? limit,
  int? queryLimit,
  bool remote = true,
  String? relayGroup,
  AndFunction and,
  WhereFunction where,
}) {
  final req = RequestFilter(
    ids: ids,
    kinds: kinds,
    authors: authors,
    tags: tags,
    search: search,
    since: since,
    until: until,
    limit: limit,
    queryLimit: queryLimit,
    remote: remote,
    relayGroup: relayGroup,
    where: where,
    and: and,
  );
  return _requestNotifierProvider(req);
}

/// Syntax-sugar for `requestNotifierProvider(RequestFilter<E>(...))`
/// with type [E] (one specific kind), [remote] is true by default
AutoDisposeStateNotifierProvider<RequestNotifier<E>, StorageState<E>>
    query<E extends Model<E>>({
  Set<String>? ids,
  Set<String>? authors,
  Map<String, Set<String>>? tags,
  String? search,
  DateTime? since,
  DateTime? until,
  int? limit,
  int? queryLimit,
  bool remote = true,
  String? relayGroup,
  WhereFunction<E> where,
  AndFunction<E> and,
}) {
  final req = RequestFilter<E>(
    ids: ids,
    authors: authors,
    tags: tags,
    search: search,
    since: since,
    until: until,
    limit: limit,
    queryLimit: queryLimit,
    remote: remote,
    relayGroup: relayGroup,
    where: _castWhere(where),
    and: _castAnd(and),
  );
  return _requestNotifierProvider<E>(req);
}

/// Syntax sugar for watching one model of type [E],
/// [remote] is true by default
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>
    model<E extends Model<E>>(E model,
        {AndFunction<E> and, bool remote = true}) {
  // Note: does not need kind or other arguments as it queries by ID
  final req =
      RequestFilter<E>(ids: {model.id}, and: _castAnd(and), remote: remote);
  return _requestNotifierProvider<E>(req);
}

typedef AndFunction<E extends Model<dynamic>> = Set<Relationship<Model>>
    Function(E)?;

typedef WhereFunction<E extends Model<dynamic>> = bool Function(E)?;

AndFunction _castAnd<E extends Model<E>>(AndFunction<E> andFn) {
  return andFn == null ? null : (e) => andFn(e as E);
}

WhereFunction _castWhere<E extends Model<E>>(WhereFunction<E> whereFn) {
  return whereFn == null ? null : (e) => whereFn(e as E);
}

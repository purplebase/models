part of models;

/// A request notifier takes a [Request]
/// that it uses to query and then filter incoming
/// events from [StorageNotifier]
class RequestNotifier<E extends Model<dynamic>>
    extends StateNotifier<StorageState<E>> {
  final Ref ref;
  final Request<E> req;
  final Source source;
  final StorageNotifier storage;

  RequestNotifier(this.ref, this.req, this.source)
      : storage = ref.read(storageNotifierProvider.notifier),
        super(StorageLoading([])) {
    // If no filters were provided, do nothing
    if (req.filters.isEmpty) {
      return;
    }

    // Trigger initial fetch/query
    _fetchAndQuery(req, source).then((models) {
      if (mounted) {
        state = StorageData(models);
      }
    });

    // Listen for storage which constantly emits updated IDs,
    // and query it back with the current req
    final sub = ref.listen(storageNotifierProvider, (_, storageState) async {
      if (!mounted) return;

      if (storageState is InternalStorageData &&
          storageState.updatedIds.isNotEmpty) {
        // Incoming are the IDs of *any* new models in local storage,
        // so restrict req to them and check if they apply
        // Since only local storage should be checked pass [LocalQuery]
        // use `fetchAndQuery` as it will also check for watched relationships
        final updatedReq = req.filters
            .map((f) => f.copyWith(ids: storageState.updatedIds))
            .toRequest();
        final updatedModels = await _fetchAndQuery(updatedReq, LocalSource());

        if (updatedModels.isNotEmpty) {
          // As replaceable events maintain their IDs across updates,
          // we remove all updated models from the current state and
          // add them again (otherwise replaceable would not update)
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
  Future<List<E>> _fetchAndQuery(Request<E> req, Source? source) async {
    print('in fetchAndQuery');
    // Send req to relays in the background
    // TODO: Is this ok, or use a copyWith in Source?
    // final remoteOnlySource = source is RemoteSource
    //     ? RemoteSource(
    //         group: source.group, includeLocal: false, stream: source.stream)
    //     : null;
    if (source case RemoteSource(includeLocal: false)) {
      // TODO: why doesn't it await?
      storage.query(req, source: source as Source);
    }

    // Since a remote query was just performed, ensure storage.query is local
    final models = await storage.query(req, source: LocalSource());
    print('fetchAndQuery queried and got ${models.length}');

    // If relationship watchers were provided, find filters and merge,
    // then query local storage
    final andFilters = req.filters.where((f) => f.and != null);

    final filters = [
      for (final andFilter in andFilters)
        for (final m in models)
          ...andFilter.and!(m)
              .map((r) => r.req!.filters)
              .expand((f) => f)
              .nonNulls
    ];

    final mergedReq = RequestFilter.mergeMultiple(filters).toRequest();

    // Fill the cache to prepare it for sync relationships.
    // Query without hitting relays, we do that below
    // (does not pass E type argument, as these are of any kind)
    final relatedModels = await storage.query(mergedReq, source: LocalSource());
    storage.requestCache[mergedReq.subscriptionId] ??= {};
    storage.requestCache[mergedReq.subscriptionId]![mergedReq] =
        relatedModels.cast();

    // Send request filters to relays
    // TODO: Fetch may get new models that expire cache entries, is this covered?
    if (source is RemoteSource) {
      storage.query(mergedReq, source: source as Source);
    }

    return models;
  }
}

final Map<Request,
        AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>>
    _typedProviderCache = {};

/// Family of notifier providers, one per request
/// Manually caching since a factory function is needed to pass the type
_requestNotifierProvider<E extends Model<dynamic>>(
        Request<E> req, Source source) =>
    _typedProviderCache[req] ??= StateNotifierProvider.autoDispose
        .family<RequestNotifier<E>, StorageState<E>, Request<E>>(
      (ref, req) {
        return RequestNotifier(ref, req, source);
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
  Source source = const RemoteSource(),
  AndFunction and,
  WhereFunction where,
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
  );
  return _requestNotifierProvider(filter.toRequest(), source);
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
  Source source = const RemoteSource(),
  WhereFunction<E> where,
  AndFunction<E> and,
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
  );
  return _requestNotifierProvider<E>(filter.toRequest(), source);
}

/// Syntax sugar for watching one model of type [E],
/// [remote] is true by default
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>
    model<E extends Model<E>>(E model,
        {Source source = const RemoteSource(),
        AndFunction<E> and,
        bool remote = true}) {
  // Note: does not need kind or other arguments as it queries by ID
  final filter = RequestFilter<E>(ids: {model.id}, and: _castAnd(and));
  return _requestNotifierProvider<E>(filter.toRequest(), source);
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

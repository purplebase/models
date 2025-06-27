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
  final List<Request> relationshipReqs = [];

  RequestNotifier(this.ref, this.req, this.source)
      : storage = ref.read(storageNotifierProvider.notifier),
        super(StorageLoading([])) {
    if (req.filters.isEmpty) return;

    _load();

    ref.onDispose(() => storage.cancel(req));
  }

  Future<void> _load() async {
    final localLoad = await storage.query(req, source: LocalSource());
    print('local load is ${localLoad.length}');
    if (localLoad.isEmpty) {
      // If it's empty, we want to block (later allow passing a flag for this)
      final remoteLoad = await _loadRemote(returnModels: true);
      _emitNewModels([...localLoad, ...?remoteLoad]);
    } else {
      _loadRemote(returnModels: false);
      _emitNewModels(localLoad);
    }
    _startSubscription();
  }

  Future<List<E>?> _loadRemote({bool returnModels = true}) async {
    if (source is RemoteSource) {
      return storage.query(req,
          source: RemoteSource(
              group: source.group,
              stream: (source as RemoteSource).stream,
              includeLocal: false,
              returnModels: returnModels));
    }
    return null;
  }

  void _startSubscription() {
    final sub = ref.listen(storageNotifierProvider, (_, storageState) async {
      if (!mounted) return;

      if (storageState
          case InternalStorageData(req: final incomingReq, :final updatedIds)
          when updatedIds.isNotEmpty) {
        if (incomingReq == req) {
          // In case the first query did not return before EOSE, handle it here
          final newModels = await storage
              .query(RequestFilter<E>(ids: updatedIds).toRequest());
          _emitNewModels(newModels);
        } else {
          print('got another incoming req $incomingReq');
          state = StorageData(state.models);
        }
      }
    });

    ref.onDispose(() => sub.close());
  }

  List<Relationship> _getRelationshipsFrom(Iterable<Model<dynamic>> models) {
    final andFns = req.filters.map((f) => f.and).nonNulls;
    return [
      for (final andFn in andFns)
        for (final m in models) ...andFn(m)
    ];
  }

  void _emitNewModels(Iterable<Model<dynamic>> models) {
    // Filter only models of type E
    // Related models are stored in request cache, they only
    // thing to do is trigger a rebuild
    final newModels = models.whereType<E>();

    // Calculate new relationships
    final newRelReqs = [
      for (final r in _getRelationshipsFrom(models))
        if (!relationshipReqs.contains(r.req)) r.req
    ].nonNulls;
    relationshipReqs.addAll(newRelReqs);

    final bigRelReq = RequestFilter.mergeMultiple(
            newRelReqs.expand((r) => r.filters).toList())
        .toRequest();
    if (bigRelReq.filters.isNotEmpty) {
      print('firing off $bigRelReq');
      storage.query(bigRelReq,
          source: RemoteSource(
              group: source.group, includeLocal: false, returnModels: false));
    }

    // Concat and sort
    // New models take precedence in the set, as there may be replaceable IDs
    final sortedModels = {...newModels, ...state.models}.sortByCreatedAt();
    if (mounted) {
      print('emitting ${sortedModels.length}');
      state = StorageData(sortedModels);
    }
  }
}

final Map<RequestFilter,
        AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>>
    _typedProviderCache = {};

/// Family of notifier providers, one per request
/// Manually caching since a factory function is needed to pass the type
_requestNotifierProvider<E extends Model<dynamic>>(
        RequestFilter<E> filter, Source source) =>
    _typedProviderCache[filter] ??= StateNotifierProvider.autoDispose
        .family<RequestNotifier<E>, StorageState<E>, RequestFilter<E>>(
      (ref, req) {
        // Defer Request creation til this point so we leverage
        // equality on the RequestFilter at the provider level

        // Clean up cache entry when provider is disposed
        ref.onDispose(() => _typedProviderCache.remove(filter));
        return RequestNotifier(ref, filter.toRequest(), source);
      },
    )(filter);

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
  return _requestNotifierProvider(filter, source);
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
  return _requestNotifierProvider<E>(filter, source);
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
  return _requestNotifierProvider<E>(filter, source);
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

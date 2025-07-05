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
  final List<Request> relationshipRequests = [];

  RequestNotifier(this.ref, this.req, this.source)
      : storage = ref.read(storageNotifierProvider.notifier),
        super(StorageLoading([])) {
    if (req.filters.isEmpty) return;

    storage.query(req, source: source).then((models) {
      _emitNewModels(models);
      _startSubscription();
    }).catchError((e, stack) {
      if (mounted) {
        state = StorageError(state.models, exception: e, stackTrace: stack);
      } else {
        print(e);
      }
    });

    ref.onDispose(() => storage.cancel(req));
  }

  void _startSubscription() {
    final sub = ref.listen(storageNotifierProvider, (_, storageState) async {
      if (!mounted) return;

      if (storageState
          case InternalStorageData(req: final incomingReq, :final updatedIds)
          when updatedIds.isNotEmpty) {
        if (incomingReq == null) {
          // No incomingReq means saved locally, get models that apply to req
          // with the incoming updated IDs
          final newRequest =
              req.filters.map((f) => f.copyWith(ids: updatedIds)).toRequest();
          try {
            final newModels =
                await storage.query(newRequest, source: LocalSource());
            _emitNewModels(newModels);
          } catch (e, stack) {
            state = StorageError(state.models, exception: e, stackTrace: stack);
          }
        } else if (incomingReq == req) {
          try {
            // In case the first query did not return before EOSE, handle it here
            final newModels = await storage.query(
                RequestFilter<E>(ids: updatedIds).toRequest(),
                source: LocalSource());
            _emitNewModels(newModels);
          } catch (e, stack) {
            state = StorageError(state.models, exception: e, stackTrace: stack);
          }
        } else {
          // All other incomingReqs are assumed to be of some relationship
          // of this notifier's models (gross assumption)
          // TODO [cache]: Reduce refreshes here
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
    final newRelationshipRequests = [
      for (final r in _getRelationshipsFrom(models))
        if (!relationshipRequests.contains(r.req)) r.req
    ].nonNulls;
    relationshipRequests.addAll(newRelationshipRequests);

    final mergedRelationshipRequest = RequestFilter.mergeMultiple(
            newRelationshipRequests.expand((r) => r.filters).toList())
        .toRequest();
    if (mergedRelationshipRequest.filters.isNotEmpty &&
        source is RemoteSource) {
      storage.query(mergedRelationshipRequest,
          source: RemoteSource(
              group: (source as RemoteSource).group, background: true));
    }

    // Handle replaceable events: remove old models with same addressable ID
    final existingModels = state.models.toList();
    final modelsToKeep = <E>[];

    for (final existingModel in existingModels) {
      // Check if any new model has the same addressable ID as this existing model
      final hasReplacement = newModels.any((newModel) =>
          newModel is ReplaceableModel &&
          existingModel is ReplaceableModel &&
          newModel.id == existingModel.id);

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
  Source source = const LocalAndRemoteSource(background: true),
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
  Source source = const LocalAndRemoteSource(background: true),
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
        {Source source = const LocalAndRemoteSource(background: true),
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

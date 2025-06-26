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
  var _relationships = <Relationship>[];

  RequestNotifier(this.ref, this.req, this.source)
      : storage = ref.read(storageNotifierProvider.notifier),
        super(StorageLoading([])) {
    if (req.filters.isEmpty) return;

    storage
        .query(req, source: source)
        .then(_handleQueryResult)
        .catchError(_handleQueryError);

    final sub = ref.listen(storageNotifierProvider, (_, storageState) async {
      if (!mounted) return;

      if (storageState
          case InternalStorageData(req: final incomingReq, :final updatedIds)
          when updatedIds.isNotEmpty) {
        await _processIncomingUpdate(incomingReq, updatedIds);
      }
    });

    ref.onDispose(() => sub.close());
    ref.onDispose(() => storage._requestCache.remove(req));
    ref.onDispose(() => storage.cancel(req));
  }

  Future<void> _handleQueryResult(List<E> models) async {
    await _updateRelationships(models);
    _emitNewModels(models);
  }

  void _handleQueryError(error) {
    // Handle timeouts, network errors, etc.
    print('Query failed: $error');
    // Keep in loading state - could implement retry logic here
    // For now, the background retries will eventually trigger the listener
  }

  Future<void> _processIncomingUpdate(
      Request? incomingReq, Set<String> updatedIds) async {
    print('listener received $updatedIds - $incomingReq');

    try {
      final mainAffected = _requestsCouldOverlap(incomingReq, req);
      final relationshipRequests =
          _findAffectedRelationshipRequests(incomingReq);

      var updatedModels = <E>[];
      var relationshipUpdated = false;

      // Handle main models
      if (mainAffected) {
        // TODO: How would potential deletions (kind 5) work in this case?
        updatedModels = await _queryMainModels(updatedIds);
        // Always update relationships when main models are affected, even if no new models
        await _updateRelationships([...updatedModels, ...state.models]);

        if (updatedModels.isNotEmpty) {
          _emitNewModels(updatedModels);
        }
      }

      // Handle relationships
      if (relationshipRequests.isNotEmpty) {
        await _updateRelationshipData(relationshipRequests, updatedIds);
        relationshipUpdated = true;
      }

      // Emit updates for relationship changes only if no main model updates
      if (updatedModels.isEmpty && relationshipUpdated) {
        state = StorageData(state.models);
      }
    } catch (error, stackTrace) {
      print('Error processing update: $error');
      print('Stack trace: $stackTrace');

      // Could implement retry logic or fallback to re-querying everything
      // For now, log and continue to prevent breaking the notifier
    }
  }

  Future<List<E>> _queryMainModels(Set<String> updatedIds) {
    final validFilters =
        req.filters.map((f) => _intersectIds(f, updatedIds)).nonNulls.toList();

    if (validFilters.isEmpty) return Future.value([]);

    return storage.query<E>(Request(validFilters), source: LocalSource());
  }

  RequestFilter<E>? _intersectIds(
      RequestFilter<E> filter, Set<String> updatedIds) {
    final intersection = filter.ids.intersection(updatedIds);
    return intersection.isEmpty ? null : filter.copyWith(ids: intersection);
  }

  RequestFilter? _intersectIdsGeneric(
      RequestFilter filter, Set<String> updatedIds) {
    if (filter.ids.isEmpty) return filter.copyWith(ids: updatedIds);
    final intersection = filter.ids.intersection(updatedIds);
    return intersection.isEmpty ? null : filter.copyWith(ids: intersection);
  }

  Future<void> _updateRelationships(Iterable<Model<dynamic>> models) async {
    final oldRelationships = {..._relationships};
    _relationships = _getRelationshipsFrom(models);

    // Fire remote queries for new relationships only
    final newRelationships =
        _relationships.toSet().difference(oldRelationships);
    final removedRelationships =
        oldRelationships.difference(_relationships.toSet());

    if (newRelationships.isNotEmpty) {
      storage.internalMultipleQuery(
          newRelationships.map((r) => r.req).nonNulls.toList(),
          source: RemoteSource(returnModels: false, group: source.group));
    }

    // Cleanup removed relationships from cache
    if (removedRelationships.isNotEmpty) {
      final cache = storage._requestCache[req];
      if (cache != null) {
        for (final removedRel in removedRelationships) {
          if (removedRel.req != null) {
            cache.remove(removedRel.req!);
          }
        }
      }
    }
  }

  Future<void> _updateRelationshipData(
      List<Request> affectedRequests, Set<String> updatedIds) async {
    final relationshipsByRequest = <Request, List<Relationship>>{};

    // Group relationships by request
    for (final rel in _relationships) {
      if (rel.req != null && affectedRequests.contains(rel.req!)) {
        relationshipsByRequest.putIfAbsent(rel.req!, () => []).add(rel);
      }
    }

    // Create modified requests with ID intersection
    final modifiedRequests = <MapEntry<Request, Request>>[];
    for (final originalReq in relationshipsByRequest.keys) {
      final validFilters = originalReq.filters
          .map((f) => _intersectIdsGeneric(f, updatedIds))
          .nonNulls
          .toList();

      if (validFilters.isNotEmpty) {
        modifiedRequests.add(MapEntry(originalReq, Request(validFilters)));
      }
    }

    if (modifiedRequests.isEmpty) return;

    print('querying with $modifiedRequests');
    final results = await storage.internalMultipleQuery(
        modifiedRequests.map((e) => e.value).toList(),
        source: LocalSource());
    print('results: $results');

    // Update cache using original request as key
    for (final entry in modifiedRequests) {
      final originalReq = entry.key;
      final modifiedReq = entry.value;
      final models = results[modifiedReq] ?? [];

      // Update all relationships that share this original request
      for (final rel in relationshipsByRequest[originalReq]!) {
        storage._requestCache.putIfAbsent(req, () => {})[rel.req!] =
            models.toList().cast();
      }
    }
  }

  List<Relationship> _getRelationshipsFrom(Iterable<Model<dynamic>> models) {
    final andFns = req.filters.map((f) => f.and).nonNulls;
    return [
      for (final andFn in andFns)
        for (final m in models) ...andFn(m)
    ];
  }

  /// Checks if an incoming request could potentially overlap with a target request
  /// by attempting to merge their filters. Returns true if any filters can be merged.
  bool _requestsCouldOverlap(Request? incomingReq, Request targetReq) {
    if (incomingReq == null) return false;

    for (final incomingFilter in incomingReq.filters) {
      for (final targetFilter in targetReq.filters) {
        final mergeResult = RequestFilter.merge(incomingFilter, targetFilter);
        if (mergeResult.length == 1) {
          return true; // Filters can be merged, so there's potential overlap
        }
      }
    }
    return false; // No filters can be merged, no overlap possible
  }

  /// Returns relationship requests that could be affected by the incoming request
  List<Request> _findAffectedRelationshipRequests(Request? incomingReq) {
    if (incomingReq == null) return [];

    final affectedRequests = <Request>[];

    for (final relationship in _relationships) {
      if (relationship.req != null &&
          _requestsCouldOverlap(incomingReq, relationship.req!)) {
        affectedRequests.add(relationship.req!);
      }
    }

    return affectedRequests;
  }

  void _emitNewModels(Iterable<Model<dynamic>> models) {
    // Filter only models of type E
    // Related models are stored in request cache, they only
    // thing to do is trigger a rebuild
    final newModels = models.whereType<E>();

    // Concat and sort
    // New models take precedence in the set, as there may be replaceable IDs
    final sortedModels = {...newModels, ...state.models}.sortByCreatedAt();
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

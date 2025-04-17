part of models;

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

    // Fetch models from local storage, fire request to relays
    Future<List<E>> fetchAndQuery(RequestFilter<E> req) async {
      // Send req to relays in the background (pre-EOSE + streaming)
      storage.fetch(req);

      // And ensure query is run in local storage only
      final models = await storage.query(req.copyWith(remote: false));

      if (req.and != null) {
        final reqs = {
          for (final m in models) ...req.and!(m).map((r) => r.req).nonNulls
        };
        final mergedReqs = mergeMultipleRequests(reqs.toList());

        for (final r in mergedReqs) {
          // Query without hitting relays, we do that below
          // (does not pass E type argument, as these are of any kind)
          final relatedModels = await storage.query(r.copyWith(remote: false));
          storage.requestCache[r.subscriptionId] ??= {};
          storage.requestCache[r.subscriptionId]![r] = relatedModels.cast();
          // Send request filters to relays
          storage.fetch(r);
        }
      }
      return models;
    }

    fetchAndQuery(req).then((models) {
      if (mounted) {
        state = StorageData([...state.models, ...models]);
      }
    });

    // Listen for storage updates
    final sub = ref.listen(storageNotifierProvider, (_, signal) async {
      if (!mounted) return;

      if (signal case (final incomingIds, final responseMetadata)) {
        if (req.restrictToSubscription &&
            responseMetadata.subscriptionId! != req.subscriptionId) {
          return;
        }

        // We do not want defaults here (just an empty set) so we can
        // match exactly with user-specified relays when the
        // restrictToRelays argument is true
        final relayUrls = storage.config
            .getRelays(relayGroup: req.relayGroup, useDefault: false);

        // If none of the relayUrls are in the incoming IDs, skip
        if (req.restrictToRelays &&
            !responseMetadata.relayUrls.any((r) => relayUrls.contains(r))) {
          return;
        }

        // Incoming are the IDs of *any* new models in local storage,
        // so restrict req to them and check if they apply
        final updatedReq = req.copyWith(ids: incomingIds, remote: false);
        final updatedModels = await fetchAndQuery(updatedReq);

        if (updatedModels.isNotEmpty) {
          // Take care of removing old versions of replaced events
          final updatedIds = updatedModels.map((m) => m.id);
          state.models.removeWhere((m) => updatedIds.contains(m.id));

          // Concat and sort
          final sortedModels = {...state.models, ...updatedModels}
              .sortedByCompare((m) => m.createdAt.millisecondsSinceEpoch,
                  (a, b) => b.compareTo(a));
          if (mounted) {
            state = StorageData(sortedModels);
          }
        }
      }
    });

    ref.onDispose(() => storage.requestCache.remove(req.subscriptionId));
    ref.onDispose(() => sub.close());
    ref.onDispose(() => storage.cancel(req));
  }

  Future<void> save(Set<Model> models) async {
    await storage.save(models);
  }
}

final Map<RequestFilter,
        AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>>
    _typedProviderCache = {};

/// Family of notifier providers, one per request
/// Manually caching since a factory function is needed to pass the type
requestNotifierProvider<E extends Model<dynamic>>(RequestFilter<E> req) =>
    _typedProviderCache[req] ??= StateNotifierProvider.autoDispose
        .family<RequestNotifier<E>, StorageState<E>, RequestFilter<E>>(
      (ref, req) {
        ref.onDispose(() => print('disposing provider'));
        return RequestNotifier(ref, req);
      },
    )(req);

/// Syntax-sugar for `requestNotifierProvider(RequestFilter(...))`
/// [remote] is true by default
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
  String? on,
  bool restrictToRelays = false,
  bool restrictToSubscription = false,
  AndFunction and,
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
    relayGroup: on,
    restrictToRelays: restrictToRelays,
    restrictToSubscription: restrictToSubscription,
    and: and,
  );
  return requestNotifierProvider(req);
}

/// Syntax-sugar for `requestNotifierProvider(RequestFilter(...))` on one specific kind
/// [remote] is true by default
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
  String? on,
  bool restrictToRelays = false,
  bool restrictToSubscription = false,
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
    relayGroup: on,
    restrictToRelays: restrictToRelays,
    restrictToSubscription: restrictToSubscription,
    and: _castAnd(and),
  );
  return requestNotifierProvider<E>(req);
}

/// Syntax sugar for watching one model
/// [remote] is true by default
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>
    model<E extends Model<E>>(E model,
        {AndFunction<E> and, bool remote = true}) {
  // Note: does not need kind as it queries by ID
  final req =
      RequestFilter(ids: {model.id}, and: _castAnd(and), remote: remote);
  return requestNotifierProvider(req);
}

AndFunction _castAnd<E extends Model<E>>(AndFunction<E> andFn) {
  return andFn == null ? null : (e) => andFn(e as E);
}

typedef AndFunction<E extends Model<dynamic>> = Set<Relationship<Model>>
    Function(E)?;

// State

sealed class StorageState<E extends Model<dynamic>> with EquatableMixin {
  final List<E> models;
  const StorageState(this.models);

  @override
  List<Object?> get props => [models];

  @override
  String toString() {
    return '[$runtimeType] $models';
  }
}

final class StorageLoading<E extends Model<dynamic>> extends StorageState<E> {
  StorageLoading(super.models);
}

final class StorageData<E extends Model<dynamic>> extends StorageState<E> {
  StorageData(super.models);
}

final class StorageError<E extends Model<dynamic>> extends StorageState<E> {
  final Exception exception;
  final StackTrace? stackTrace;
  StorageError(super.modelsWithMetadata,
      {required this.exception, this.stackTrace});
}

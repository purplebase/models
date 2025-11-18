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
  final List<Request> relationshipRequests = [];
  final List<Request> mergedRelationshipRequests = [];

  RequestNotifier(this.ref, this.req, this.source, [this.andSource])
    : storage = ref.read(storageNotifierProvider.notifier),
      super(StorageLoading([])) {
    if (req.filters.isEmpty) return;

    // Extract prefix from the request's subscriptionId to reuse for internal queries
    final prefix = req.subscriptionId.contains('-')
        ? req.subscriptionId.split('-').first
        : null;

    storage
        .query(req, source: source, subscriptionPrefix: prefix)
        .then((models) {
          _emitNewModels(models);
          _startSubscription();
        })
        .catchError((e, stack) {
          if (mounted) {
            state = StorageError(state.models, exception: e, stackTrace: stack);
          } else {
            print(e);
          }
        });

    ref.onDispose(() async {
      // Cancel main request
      await storage.cancel(req);

      // Cancel all merged relationship requests (the actual subscriptions)
      await Future.wait(
        mergedRelationshipRequests.map((mergedReq) => storage.cancel(mergedReq)),
      );
    });
  }

  void _startSubscription() {
    final sub = ref.listen(storageNotifierProvider, (_, storageState) async {
      if (!mounted) return;

      if (storageState case InternalStorageData(
        req: final incomingReq,
        :final updatedIds,
      ) when updatedIds.isNotEmpty) {
        if (incomingReq == null ||
            incomingReq.subscriptionId == req.subscriptionId) {
          await _refreshModelsFromLocal();
        } else {
          // Check if any updatedIds affect our models (for replaceable updates)
          final ourIds = state.models.map((m) => m.id).toSet();
          final hasRelevantUpdate = updatedIds.any((id) => 
            ourIds.contains(id) || // Addressable ID match
            state.models.any((m) => m.event.id == id) // Event ID match
          );
          
          if (hasRelevantUpdate) {
            // Replaceable model was updated - refresh from storage
            await _refreshModelsFromLocal();
          } else {
            // Unrelated update (probably a relationship)
            _processNewRelationships(state.models);
            state = StorageData(state.models);
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
        for (final m in models) ...andFn(m),
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

    if (mergedRelationshipRequest.filters.isNotEmpty &&
        source is RemoteSource) {
      // Store the merged request for proper cleanup on dispose
      mergedRelationshipRequests.add(mergedRelationshipRequest);

      // Use custom andSource if provided, otherwise derive from parent source
      final relationshipSource = andSource ?? _deriveRelationshipSource();

      storage.query(
        mergedRelationshipRequest,
        source: relationshipSource,
        subscriptionPrefix: prefix,
      );
    }
  }

  /// Derive relationship source from parent source when andSource is not provided
  Source _deriveRelationshipSource() {
    if (source is! RemoteSource) return source;

    final remoteSource = source as RemoteSource;

    // Preserve LocalAndRemoteSource type and inherit parameters from parent
    // For RemoteSource, enable background for relationships
    return source is LocalAndRemoteSource
        ? remoteSource.copyWith()
        : remoteSource.copyWith(background: true);
  }

  Future<void> _refreshModelsFromLocal() async {
    try {
      final refreshedModels = await storage.query(
        req,
        source: LocalSource(),
      );
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
  Source source = const LocalAndRemoteSource(background: true),
  Source? andSource,
  String? subscriptionPrefix,
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
  Source source = const LocalAndRemoteSource(background: true),
  Source? andSource,
  String? subscriptionPrefix,
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
  Source source = const LocalAndRemoteSource(background: true),
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
    Set<Relationship<Model>> Function(E)?;

typedef WhereFunction<E extends Model<dynamic>> = bool Function(E)?;

AndFunction _castAnd<E extends Model<E>>(AndFunction<E> andFn) {
  return andFn == null ? null : (e) => andFn(e as E);
}

WhereFunction _castWhere<E extends Model<E>>(WhereFunction<E> whereFn) {
  return whereFn == null ? null : (e) => whereFn(e as E);
}

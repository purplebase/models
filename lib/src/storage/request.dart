import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';

class RequestNotifier<E extends Event<dynamic>>
    extends StateNotifier<StorageState<E>> {
  final Ref ref;
  final RequestFilter req;
  final StorageNotifier storage;
  var applyLimit = true;
  final List<RequestFilter> andReqs = [];

  RequestNotifier(this.ref, this.req)
      : storage = ref.read(storageNotifierProvider.notifier),
        super(StorageLoading([])) {
    // If no filters were provided, do nothing
    if (req.toMap().isEmpty) {
      return;
    }

    // Fetch events from local storage, fire request to relays
    Future<List<Event>> fn(RequestFilter req) async {
      // Send request filter to relays
      storage.send(req);

      final events = await storage.query(req);

      if (req.and != null) {
        final reqs = {
          for (final e in events)
            ...req.and!(e)
                .map((r) => r.req?.copyWith(storageOnly: req.storageOnly))
                .nonNulls
        };

        // TODO: Merge reqs here; and allow querying multiple reqs
        final mergedReqs = [];
        for (final r in reqs) {
          final events = await storage.query(r);
          andReqs.add(r);
          storage.requestCache[r.subscriptionId] ??= {};
          storage.requestCache[r.subscriptionId]![r] = events;
        }
        // Send request filters to relays
        for (final r in mergedReqs) {
          storage.send(r);
        }
      }

      return events;
    }

    fn(req).then((events) {
      if (mounted) {
        state = StorageData([...state.models, ...events.cast<E>()]);
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

        // TODO: Use defaults? Explain why
        final relayUrls =
            storage.config.getRelays(relayGroup: req.on, useDefault: false);

        // If none of the relayUrls are in the incoming IDs, skip
        if (req.restrictToRelays &&
            !responseMetadata.relayUrls.any((r) => relayUrls.contains(r))) {
          return;
        }

        List<Event> events;

        // Incoming are the IDs of *any* new events in local storage,
        // so restrict req to them and check if they apply

        final finalIncomingIds = incomingIds.where((id) {
          // If replaceable incoming ID, only keep if in req.ids
          if (kReplaceableRegexp.hasMatch(id)) {
            return req.ids.contains(id);
          }
          // If regular incoming ID, keep
          return true;
        }).toSet();

        final updatedReq =
            req.copyWith(ids: finalIncomingIds, storageOnly: true);
        events = await fn(updatedReq);

        final List<E> sortedModels = {...state.models, ...events.cast<E>()}
            .sortedByCompare((m) => m.createdAt.millisecondsSinceEpoch,
                (a, b) => b.compareTo(a));
        if (mounted) {
          state = StorageData(sortedModels);
        }
      }
    });

    ref.onDispose(() => storage.requestCache.remove(req.subscriptionId));
    ref.onDispose(() => sub.close());
    ref.onDispose(() => storage.cancel(req));
  }

  Future<void> save(Set<Event> events) async {
    await storage.save(events);
  }
}

final Map<RequestFilter,
        AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>>
    _typedProviderCache = {};

/// Family of notifier providers, one per request.
/// Meant to be overridden, defaults to dummy implementation
requestNotifierProviderFactory<E extends Event<dynamic>>(RequestFilter req) =>
    _typedProviderCache[req] ??= StateNotifierProvider.autoDispose
        .family<RequestNotifier<E>, StorageState<E>, RequestFilter>(
      (ref, req) {
        ref.onDispose(() => print('disposing provider'));
        return RequestNotifier(ref, req);
      },
    )(req);

/// Syntax-sugar for `requestNotifierProvider(RequestFilter(...))`
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState> query({
  Set<String>? ids,
  Set<int>? kinds,
  Set<String>? authors,
  Map<String, Set<String>>? tags,
  String? search,
  DateTime? since,
  DateTime? until,
  int? limit,
  int? queryLimit,
  bool storageOnly = false,
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
    storageOnly: storageOnly,
    on: on,
    restrictToRelays: restrictToRelays,
    restrictToSubscription: restrictToSubscription,
    and: and,
  );
  return requestNotifierProviderFactory(req);
}

/// Syntax-sugar for `requestNotifierProvider(RequestFilter(...))` on one specific kind
AutoDisposeStateNotifierProvider<RequestNotifier<E>, StorageState<E>>
    queryType<E extends Event<E>>({
  Set<String>? ids,
  Set<String>? authors,
  Map<String, Set<String>>? tags,
  String? search,
  DateTime? since,
  DateTime? until,
  int? limit,
  int? queryLimit,
  bool storageOnly = false,
  String? on,
  bool restrictToRelays = false,
  bool restrictToSubscription = false,
  AndFunction<E> and,
}) {
  final req = RequestFilter(
    ids: ids,
    kinds: {Event.kindFor<E>()},
    authors: authors,
    tags: tags,
    search: search,
    since: since,
    until: until,
    limit: limit,
    queryLimit: queryLimit,
    storageOnly: storageOnly,
    on: on,
    restrictToRelays: restrictToRelays,
    restrictToSubscription: restrictToSubscription,
    and: _castAnd(and),
  );
  return requestNotifierProviderFactory<E>(req);
}

/// Syntax sugar for watching one model
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>
    model<E extends Event<E>>(E model,
        {AndFunction<E> and, bool storageOnly = false}) {
  // Note: does not need kind as it queries by ID
  final req = RequestFilter(
      ids: {model.id}, and: _castAnd(and), storageOnly: storageOnly);
  return requestNotifierProviderFactory(req);
}

AndFunction _castAnd<E extends Event<E>>(AndFunction<E> andFn) {
  return andFn == null ? null : (e) => andFn(e as E);
}

typedef AndFunction<E extends Event<dynamic>> = Set<Relationship<Event>>
    Function(E)?;

// State

sealed class StorageState<E extends Event<dynamic>> with EquatableMixin {
  final List<E> models;
  const StorageState(this.models);

  @override
  List<Object?> get props => [models];

  @override
  String toString() {
    return '[$runtimeType] $models';
  }
}

final class StorageLoading<E extends Event<dynamic>> extends StorageState<E> {
  StorageLoading(super.models);
}

final class StorageData<E extends Event<dynamic>> extends StorageState<E> {
  StorageData(super.models);
}

final class StorageError<E extends Event<dynamic>> extends StorageState<E> {
  final Exception exception;
  final StackTrace? stackTrace;
  StorageError(super.modelsWithMetadata,
      {required this.exception, this.stackTrace});
}

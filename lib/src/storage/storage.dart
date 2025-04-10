import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';

abstract class StorageNotifier extends StateNotifier<StorageSignal> {
  StorageNotifier() : super(StorageSignal());
  late StorageConfiguration config;

  Future<void> initialize(StorageConfiguration config) async {
    this.config = config;
  }

  Future<List<Event>> query(RequestFilter req,
      {bool applyLimit = true, Set<String>? onIds});

  /// Ideally to be used for must-have sync interfaces such relationships
  /// upon widget first load, and tests. Prefer [query] otherwise.
  List<Event> querySync(RequestFilter req,
      {bool applyLimit = true, Set<String>? onIds});

  Future<void> save(Set<Event> events, {String? relayGroup});

  Future<void> send(RequestFilter req);

  Future<void> clear([RequestFilter? req]);
}

final storageNotifierProvider =
    StateNotifierProvider<StorageNotifier, StorageSignal>(
        DummyStorageNotifier.new);

class RequestNotifier extends StateNotifier<StorageState> {
  final Ref ref;
  final RequestFilter req;
  final StorageNotifier storage;
  var applyLimit = true;

  RequestNotifier(this.ref, this.req)
      : storage = ref.read(storageNotifierProvider.notifier),
        super(StorageLoading([])) {
    // If no filters were provided, do nothing
    if (req.toMap().isEmpty) {
      return;
    }

    // Execute query and notify
    Future<List<Event>> fn(RequestFilter req) async {
      final events = await storage.query(req, applyLimit: applyLimit);

      applyLimit = false;
      if (!req.storageOnly) {
        // Send request filter to relays
        storage.send(req);
      }

      if (req.and != null) {
        final reqs = {
          for (final e in events)
            ...req.and!(e)
                .map((r) => r.req.copyWith(storageOnly: req.storageOnly))
        };
        // TODO: Optimize hard as these are sync reads
        final relEvents = await Future.wait(reqs.map(fn));
        for (final list in relEvents) {
          for (final e in list) {
            events.add(e);
          }
        }
      }

      return events;
    }

    fn(req).then((events) {
      state = StorageData(events);
    });

    final sub = ref.listen(storageNotifierProvider, (_, signal) async {
      if (signal.record case (final ids, final responseMetadata)) {
        if (req.restrictToSubscription &&
            responseMetadata.subscriptionId! != req.subscriptionId) {
          return;
        }

        final relayUrls = storage.config.getRelays(req.on, false);

        // If none of the relayUrls are in the incoming IDs, skip
        if (req.restrictToRelays &&
            !responseMetadata.relayUrls.any((r) => relayUrls.contains(r))) {
          return;
        }

        // Signal gives us the newly saved models, *if* we pass it through
        // the `onIds` callback we get them filtered to the supplied `req`,
        // otherwise it applies `req` to all stored models
        final events =
            await storage.query(req, applyLimit: applyLimit, onIds: ids);

        // TODO: Need to query for relationships here too

        final sortedModels = {...state.models, ...events}.sortedByCompare(
            (m) => m.createdAt.millisecondsSinceEpoch,
            (a, b) => b.compareTo(a));
        state = StorageData(sortedModels);
      }
    });

    ref.onDispose(() {
      sub.close();
    });
  }

  Future<void> save(Set<Event> events) async {
    await storage.save(events);
  }
}

/// Family of notifier providers, one per request.
/// Meant to be overridden, defaults to dummy implementation
final requestNotifierProvider = StateNotifierProvider.autoDispose
    .family<RequestNotifier, StorageState, RequestFilter>(
  (ref, req) {
    ref.onDispose(() => print('disposing provider'));
    return RequestNotifier(ref, req);
  },
);

/// Syntax-sugar for `requestNotifierProvider(RequestFilter(...))`
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState> query({
  Set<int>? kinds,
  Set<String>? ids,
  Set<String>? authors,
  Map<String, Set<String>>? tags,
  String? search,
  DateTime? since,
  DateTime? until,
  int? limit,
  AndFunction and,
  bool storageOnly = false,
}) {
  final req = RequestFilter(
      kinds: kinds,
      ids: ids,
      authors: authors,
      tags: tags,
      search: search,
      since: since,
      until: until,
      limit: limit,
      and: and,
      storageOnly: storageOnly);
  return requestNotifierProvider(req);
}

/// Syntax-sugar for `requestNotifierProvider(RequestFilter(...))` on one specific kind
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>
    queryType<E extends Event<E>>({
  Set<String>? ids,
  Set<String>? authors,
  Map<String, Set<String>>? tags,
  String? search,
  DateTime? since,
  DateTime? until,
  int? limit,
  AndFunction<E> and,
  bool storageOnly = false,
}) {
  final req = RequestFilter(
      kinds: {Event.kindFor<E>()},
      ids: ids,
      authors: authors,
      tags: tags,
      search: search,
      since: since,
      until: until,
      limit: limit,
      and: _castAnd(and),
      storageOnly: storageOnly);
  return requestNotifierProvider(req);
}

/// Syntax sugar for watching one model
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>
    model<E extends Event<E>>(E model,
        {AndFunction<E> and, bool storageOnly = false}) {
  final req = RequestFilter(
      ids: {model.id}, and: _castAnd(and), storageOnly: storageOnly);
  return requestNotifierProvider(req);
}

AndFunction _castAnd<E extends Event<E>>(AndFunction<E> andFn) {
  return andFn == null ? null : (e) => andFn(e as E);
}

typedef AndFunction<E extends Event<dynamic>> = Set<Relationship<Event>>
    Function(E)?;

// State

sealed class StorageState with EquatableMixin {
  final List<Event> models;
  const StorageState(this.models);

  @override
  List<Object?> get props => [models];

  @override
  String toString() {
    return '[$runtimeType] $models';
  }
}

final class StorageLoading extends StorageState {
  StorageLoading(super.models);
}

final class StorageData extends StorageState {
  StorageData(super.models);
}

final class StorageError extends StorageState {
  final Exception exception;
  final StackTrace? stackTrace;
  StorageError(super.modelsWithMetadata,
      {required this.exception, this.stackTrace});
}

class StorageSignal {
  final (Set<String>, ResponseMetadata)? record;
  StorageSignal([this.record]);
}

// Fast hash

int fastHash(List<int> data, [int seed = 0]) {
  // Initialize hash with the seed XOR the length of data.
  int hash = seed ^ data.length;

  // Process each byte in the input data.
  for (var byte in data) {
    // This is a simple hash mixing step:
    // Multiply by 33 (via a left-shift of 5 added to the hash) and XOR with the current byte.
    hash = ((hash << 5) + hash) ^ byte;
  }

  // Return the hash as an unsigned 32-bit integer.
  return hash & 0xFFFFFFFF;
}

int fastHashString(String input, [int seed = 0]) {
  // Convert the string to its code units (UTF-16 values) and hash.
  final bytes = input.codeUnits;
  return fastHash(bytes, seed);
}

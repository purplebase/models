import 'dart:math';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';

import 'dummy_notifier.dart';

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

  Future<void> save(Set<Event> events);

  Future<void> send(RequestFilter req, {Set<String>? relayUrls});

  Future<void> clear([RequestFilter? req]);

  Future<void> close();
}

final storageNotifierProvider =
    StateNotifierProvider<StorageNotifier, StorageSignal>(
        DummyStorageNotifier.new);

class RequestNotifier extends StateNotifier<StorageState> {
  final RequestFilter req;
  final Ref ref;
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
      // print('setting initial state, ${events.length}');

      applyLimit = false;
      if (!req.storageOnly) {
        // Send request filter to relays
        storage.send(req);
      }

      if (req.and != null) {
        // final req2 = req.and!(events.first).map((r) => r.req).first;
        final reqs = [for (final e in events) ...req.and!(e).map((r) => r.req)];

        final relEvents = await Future.wait(reqs.map(fn));
        events.addAll(relEvents.expand((e) => e));
      }

      return events;
    }

    fn(req).then((events) {
      state = StorageData(events);
    });

    final sub = ref.listen(storageNotifierProvider, (_, signal) async {
      state = StorageLoading(state.models);
      // Signal gives us the newly saved models, *if* we pass it through
      // the `onModels` callback we get them filtered to the supplied `req`,
      // otherwise it applies `req` to all stored models
      final events = await storage.query(req,
          applyLimit: applyLimit, onIds: signal.eventIds);
      state = StorageData({...state.models, ...events}.sortedByCompare(
          (m) => m.createdAt.millisecondsSinceEpoch, (a, b) => b.compareTo(a)));
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
    // TODO: Using keepAlive to make tests work, isn't it contradictory to auto-dispose?
    ref.keepAlive();
    ref.onDispose(() => print('disposing provider'));
    return RequestNotifier(ref, req);
  },
);

/// Syntax-sugar for `requestNotifierProvider(RequestFilter(...))`
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState> query(
    {Set<int>? kinds,
    Set<String>? ids,
    Set<String>? authors,
    Map<String, Set<String>>? tags,
    String? search,
    DateTime? since,
    DateTime? until,
    int? limit,
    AndFunction and,
    bool storageOnly = false}) {
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
    queryType<E extends Event<E>>(
        {Set<String>? ids,
        Set<String>? authors,
        Map<String, Set<String>>? tags,
        String? search,
        DateTime? since,
        DateTime? until,
        int? limit,
        AndFunction<E> and,
        bool storageOnly = false}) {
  // final AndFunction fn = and;
  final req = RequestFilter(
      kinds: {1}, // TODO: Fetch right kind
      ids: ids,
      authors: authors,
      tags: tags,
      search: search,
      since: since,
      until: until,
      limit: limit,
      and: and == null ? null : (e) => and(e as E),
      storageOnly: storageOnly);
  return requestNotifierProvider(req);
}

/// Syntax sugar for watching one model
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState> model(
    Event model,
    {bool storageOnly = false}) {
  final req = RequestFilter(ids: {model.id}, storageOnly: storageOnly);
  return requestNotifierProvider(req);
}

// Request filter

typedef AndFunction<E extends Event<dynamic>> = Set<Relationship<Event>>
    Function(E)?;

class RequestFilter extends Equatable {
  static final _random = Random();

  late final String subscriptionId;
  final Set<String> ids;
  final Set<int> kinds;
  final Set<String> authors;
  final Map<String, Set<String>> tags;
  final String? search;
  final DateTime? since;
  final DateTime? until;
  final int? limit;
  final int? queryLimit; // Total limit including streaming
  final bool bufferUntilEose;
  final bool storageOnly;

  /// Used to provide additional filtering after the query, in Dart
  final bool Function(Event)? where;

  final AndFunction and;

  RequestFilter({
    Set<String>? ids,
    Set<String>? authors,
    Set<int>? kinds,
    Map<String, Set<String>>? tags,
    this.search,
    this.since,
    this.until,
    this.limit,
    this.queryLimit,
    this.bufferUntilEose = true,
    this.storageOnly = false,
    this.where,
    this.and,
    String? subscriptionId,
  })  : ids = ids ?? const {},
        authors = authors ?? const {},
        kinds = kinds ?? const {},
        tags = tags ?? const {} {
    // TODO: Validate ids, authors have proper format, auto-convert from npub if needed
    this.subscriptionId = subscriptionId ?? 'sub-${_random.nextInt(999999)}';
  }

  Map<String, dynamic> toMap() {
    return {
      if (ids.isNotEmpty) 'ids': ids.sorted(),
      if (kinds.isNotEmpty) 'kinds': kinds.sorted((i, j) => i.compareTo(j)),
      if (authors.isNotEmpty) 'authors': authors.sorted(),
      for (final e in tags.entries.sortedBy((e) => e.key))
        if (e.value.isNotEmpty) e.key: e.value.sorted(),
      if (since != null) 'since': since!.toSeconds(),
      if (until != null) 'until': until!.toSeconds(),
      if (limit != null) 'limit': limit,
      if (search != null) 'search': search,
    };
  }

  RequestFilter copyWith(
      {Set<String>? ids,
      Set<String>? authors,
      Set<int>? kinds,
      Map<String, Set<String>>? tags,
      String? search,
      DateTime? since,
      DateTime? until,
      int? limit,
      bool? storageOnly}) {
    return RequestFilter(
        ids: ids ?? this.ids,
        authors: authors ?? this.authors,
        kinds: kinds ?? this.kinds,
        tags: tags ?? this.tags,
        search: search ?? this.search,
        since: since ?? this.since,
        until: until ?? this.until,
        limit: limit ?? this.limit,
        queryLimit: queryLimit,
        bufferUntilEose: bufferUntilEose,
        storageOnly: storageOnly ?? this.storageOnly,
        where: where,
        subscriptionId: subscriptionId);
  }

  int get hash => fastHashString(toString());

  @override
  List<Object?> get props => [toMap()];

  @override
  String toString() {
    return toMap().toString();
  }
}

// State

sealed class StorageState {
  final List<Event> models;
  const StorageState(this.models);
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
  StorageError(super.models, {required this.exception, this.stackTrace});
}

class StorageSignal {
  final Set<String>? eventIds;
  StorageSignal([this.eventIds]);
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

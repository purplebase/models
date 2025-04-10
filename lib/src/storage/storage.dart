import 'dart:math';

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

  Future<void> send(RequestFilter req, {String? relayGroup});

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

  RequestNotifier(this.ref, this.req, String? relayGroup)
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
        storage.send(req, relayGroup: relayGroup);
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
      if (signal.record case (final ids, _)) {
        // TODO: metadata can be used here to restrict by relay or sub

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
final requestNotifierProvider = StateNotifierProvider.autoDispose.family<
    RequestNotifier, StorageState, (RequestFilter req, String? relayGroup)>(
  (ref, arg) {
    final (req, relayGroup) = arg;
    ref.onDispose(() => print('disposing provider'));
    return RequestNotifier(ref, req, relayGroup);
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
    bool storageOnly = false,
    String? on}) {
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
  return requestNotifierProvider((req, on));
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
        bool storageOnly = false,
        String? on}) {
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
  return requestNotifierProvider((req, on));
}

/// Syntax sugar for watching one model
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>
    model<E extends Event<E>>(E model,
        {AndFunction<E> and, bool storageOnly = false, String? on}) {
  final req = RequestFilter(
      ids: {model.id}, and: _castAnd(and), storageOnly: storageOnly);
  return requestNotifierProvider((req, on));
}

AndFunction _castAnd<E extends Event<E>>(AndFunction<E> andFn) {
  return andFn == null ? null : (e) => andFn(e as E);
}

// Request filter

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
  final Set<String> relays;

  /// Used to provide additional post-query filtering in Dart
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
    Set<String>? relays,
    String? subscriptionId,
  })  : ids = ids ?? const {},
        authors = authors ?? const {},
        kinds = kinds ?? const {},
        tags = tags ?? const {},
        relays = relays ?? const {} {
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

typedef AndFunction<E extends Event<dynamic>> = Set<Relationship<Event>>
    Function(E)?;

// Response metadata

class ResponseMetadata with EquatableMixin {
  final String? subscriptionId;
  final Set<String> relayUrls;
  ResponseMetadata({this.subscriptionId, required this.relayUrls});

  ResponseMetadata copyWith(String? subscriptionId, Set<String>? relayUrls) {
    return ResponseMetadata(
      subscriptionId: subscriptionId ?? this.subscriptionId,
      relayUrls: relayUrls ?? this.relayUrls,
    );
  }

  @override
  List<Object?> get props => [subscriptionId, relayUrls];
}

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

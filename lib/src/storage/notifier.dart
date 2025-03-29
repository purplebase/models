import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:models/src/core/extensions.dart';
import 'package:riverpod/riverpod.dart';

import '../core/event.dart';
import 'dummy_notifier.dart';

mixin Storage {
  Future<List<Event>> queryAsync(RequestFilter req,
      {bool applyLimit = true, Iterable<Event>? onModels});
  List<Event> query(RequestFilter req,
      {bool applyLimit = true, Iterable<Event>? onModels});
  Future<void> save(Iterable<Event> events);
  Future<void> clear([RequestFilter? req]);
}

abstract class StorageNotifier extends StateNotifier<StorageSignal>
    with Storage {
  StorageNotifier() : super(StorageSignal());
}

final storageNotifierProvider =
    StateNotifierProvider.autoDispose<StorageNotifier, StorageSignal>(
  (ref) {
    // TODO: Using keepAlive to make tests work, isn't it contradictory to auto-dispose?
    ref.keepAlive();
    ref.onDispose(() => print('disposing provider'));
    return DummyStorageNotifier(ref);
  },
);

abstract class RequestNotifier extends StateNotifier<StorageState> {
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
    storage.queryAsync(req, applyLimit: applyLimit).then((events) {
      // print('setting initial state, ${events.length}');
      state = StorageData(events);
      applyLimit = false;
      if (!req.storageOnly) {
        // Send request filter to relays
        send(req);
      }
    });

    final sub = ref.listen(storageNotifierProvider, (_, signal) async {
      state = StorageLoading(state.models);
      // Signal gives us the newly saved models, *if* we pass it through
      // the `onModels` callback we get them filtered to the supplied `req`,
      // otherwise it applies `req` to all stored models
      final events = await storage.queryAsync(req,
          applyLimit: applyLimit, onModels: signal.events);
      state = StorageData([...state.models, ...events]);
    });

    ref.onDispose(() {
      sub.close();
    });
  }

  Future<void> save(List<Event> events) async {
    await storage.save(events);
  }

  void send(RequestFilter req);
}

/// Family of notifier providers, one per request.
/// Meant to be overridden, defaults to dummy implementation
final requestNotifierProvider = StateNotifierProvider.autoDispose
    .family<RequestNotifier, StorageState, RequestFilter>(
  (ref, req) {
    // TODO: Using keepAlive to make tests work, isn't it contradictory to auto-dispose?
    ref.keepAlive();
    ref.onDispose(() => print('disposing provider'));
    return DummyRequestNotifier(ref, req);
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
      storageOnly: storageOnly);
  return requestNotifierProvider(req);
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
  final Iterable<Event>? events;
  StorageSignal([this.events]);
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

  /// Used to provide additional filtering after the query, in Dart
  final bool Function(Event)? where;

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
      if (ids.isNotEmpty) 'ids': ids.toList(),
      if (kinds.isNotEmpty) 'kinds': kinds.toList(),
      if (authors.isNotEmpty) 'authors': authors.toList(),
      for (final e in tags.entries)
        if (e.value.isNotEmpty) e.key: e.value,
      if (since != null) 'since': since!.toSeconds(),
      if (until != null) 'until': until!.toSeconds(),
      if (limit != null) 'limit': limit,
      if (search != null) 'search': search,
    };
  }

  RequestFilter copyWith({int? limit, bool? storageOnly}) {
    return RequestFilter(
        ids: ids,
        authors: authors,
        kinds: kinds,
        tags: tags,
        search: search,
        since: since,
        until: until,
        limit: limit ?? this.limit,
        queryLimit: queryLimit,
        bufferUntilEose: bufferUntilEose,
        storageOnly: storageOnly ?? this.storageOnly,
        where: where,
        subscriptionId: subscriptionId);
  }

  @override
  List<Object?> get props => [toMap()];

  @override
  String toString() {
    return toMap().toString();
  }
}

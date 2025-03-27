import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:models/src/core/utils.dart';
import 'package:riverpod/riverpod.dart';

import '../core/event.dart';
import 'dummy.dart';
import 'state.dart';

abstract class Storage {
  Future<List<Event>> queryAsync(RequestFilter req, {bool applyLimit = true});
  List<Event> query(RequestFilter req, {bool applyLimit = true});
  Future<void> save(Iterable<Event> events);
  Future<void> clear([RequestFilter? req]);
}

final storageProvider = Provider((ref) => DummyStorage(ref));

//

abstract class StorageNotifier extends StateNotifier<StorageSignal> {
  StorageNotifier() : super(StorageSignal());
  Future<void> save(List<Event> events);
  Future<void> generateDummyFor(
      {required String pubkey,
      required int kind,
      int amount = 10,
      bool stream = false});
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

//

abstract class RequestNotifier extends StateNotifier<StorageState> {
  RequestNotifier() : super(StorageLoading([]));
  void send(RequestFilter req);
}

final requestNotifierProvider = StateNotifierProvider.autoDispose
    .family<RequestNotifier, StorageState, RequestFilter>(
  (ref, req) {
    // TODO: Using keepAlive to make tests work, isn't it contradictory to auto-dispose?
    ref.keepAlive();
    ref.onDispose(() => print('disposing provider'));
    return DummyRequestNotifier(ref, req);
  },
);

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

final dummyDataProvider = StateProvider<List<Event>>((_) => []);

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
  // TODO: Add queryLimit for total limit (as limit only applies to first state)
  final int? queryLimit;
  // TODO: Implement buffer until EOSE
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

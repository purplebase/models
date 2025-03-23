import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:models/src/relay/dummy.dart';
import 'package:models/src/utils.dart';
import 'package:riverpod/riverpod.dart';

final storageNotifierProvider = StateNotifierProvider.autoDispose
    .family<StorageNotifier, StorageState, RequestFilter>(
  (ref, req) {
    // TODO: Using keepAlive to make tests work, isn't it contradictory to auto-dispose?
    ref.keepAlive();
    ref.onDispose(() => print('disposing provider'));
    return DummyStorageNotifier(ref, req);
  },
);

abstract class StorageNotifier extends StateNotifier<StorageState> {
  StorageNotifier() : super(StorageData([]));
  void send(RequestFilter req);
}

AutoDisposeStateNotifierProvider<StorageNotifier, StorageState> query(
    {Set<int>? kinds,
    Set<String>? ids,
    Set<String>? authors,
    Map<String, Set<String>>? tags,
    String? search,
    DateTime? since,
    DateTime? until,
    int? limit}) {
  final req = RequestFilter(
      kinds: kinds,
      ids: ids,
      authors: authors,
      tags: tags,
      search: search,
      since: since,
      until: until,
      limit: limit);
  return storageNotifierProvider(req);
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
  // TODO
  final bool bufferUntilEose;
  // TODO: Add queryLimit for total limit (as limit only applies to first state)

  RequestFilter({
    Set<String>? ids,
    Set<String>? authors,
    Set<int>? kinds,
    Map<String, Set<String>>? tags,
    this.search,
    this.since,
    this.until,
    this.limit,
    // TODO: Implement buffer until EOSE
    this.bufferUntilEose = true,
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
      if (since != null) 'since': since!.toInt(),
      if (until != null) 'until': until!.toInt(),
      if (limit != null) 'limit': limit,
      if (search != null) 'search': search,
    };
  }

  @override
  List<Object?> get props => [toMap()];

  @override
  String toString() {
    return toMap().toString();
  }
}

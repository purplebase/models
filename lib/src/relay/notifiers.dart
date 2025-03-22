import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:models/src/relay/dummy.dart';
import 'package:models/src/utils.dart';
import 'package:riverpod/riverpod.dart';

final relayNotifierProvider = StateProvider.autoDispose<RelayNotifier>(
  (_) => DummyRelayNotifier(),
);

abstract class RelayNotifier extends StateNotifier<RelayState> {
  RelayNotifier(super.state);
  void send(RelayRequest req, [Object? key]);
}

final _query = StateNotifierProvider.autoDispose
    .family<RelayNotifier, RelayState, RelayRequest?>((ref, req) {
  final notifier = ref.watch(relayNotifierProvider);
  if (req != null) {
    notifier.send(req);
  }
  ref.onDispose(() => print('disposed'));
  return notifier;
});

// AutoDisposeStateNotifierProvider<RelayNotifier, RelayState>
//     relaysFor<E extends Event<E>>({Set<String>? authors, int? limit}) {
//   return _query(RelayRequest(authors: authors ?? {}, limit: limit));
// }

AutoDisposeStateNotifierProvider<RelayNotifier, RelayState> relays(String label,
    [Object? key]) {
  // TODO: Restrict by label and key
  return _query(null);
}

class RelayRequest extends Equatable {
  static final _random = Random();

  late final String subscriptionId;
  final Set<String> ids;
  final Set<int> kinds;
  final Set<String> authors;
  final Map<String, dynamic> tags;
  final String? search;
  final DateTime? since;
  final DateTime? until;
  final int? limit;
  final bool bufferUntilEose;

  RelayRequest({
    this.ids = const {},
    this.kinds = const {},
    this.authors = const {},
    this.tags = const {},
    this.search,
    this.since,
    this.until,
    this.limit,
    this.bufferUntilEose = true,
  }) {
    subscriptionId = 'sub-${_random.nextInt(999999)}';
  }

  Map<String, dynamic> toMap() {
    return {
      if (ids.isNotEmpty) 'ids': ids.toList(),
      if (kinds.isNotEmpty) 'kinds': kinds.toList(),
      if (authors.isNotEmpty) 'authors': authors.toList(),
      for (final e in tags.entries)
        e.key: e.value is Iterable ? e.value.toList() : e.value,
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

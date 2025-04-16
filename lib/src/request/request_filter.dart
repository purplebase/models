// Request filter

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

class RequestFilter extends Equatable {
  static final _random = Random();

  final Set<String> ids;
  final Set<int> kinds;
  final Set<String> authors;
  final Map<String, Set<String>> tags;
  final DateTime? since;
  final DateTime? until;
  final int? limit;
  final String? search;

  // Extra arguments

  /// Provide a specific subscription ID
  late final String subscriptionId;

  /// Total limit including streaming
  final int? queryLimit;

  /// Do not query relays
  final bool remote;

  /// Send request to this relay group
  final String? on;

  /// Restrict to requested relay group
  final bool restrictToRelays;

  /// Restrict to current subscription
  final bool restrictToSubscription;

  /// Provide additional post-query filtering in Dart
  final bool Function(Event)? where;

  /// Watch relationships
  final AndFunction and;

  RequestFilter({
    Set<String>? ids,
    Set<int>? kinds,
    Set<String>? authors,
    Map<String, Set<String>>? tags,
    this.since,
    this.until,
    this.limit,
    this.search,
    // Extra arguments
    String? subscriptionId,
    this.queryLimit,
    this.remote = false,
    this.on,
    this.restrictToRelays = false,
    this.restrictToSubscription = false,
    this.where,
    this.and,
  })  : ids = ids ?? const {},
        authors = authors ?? const {},
        kinds = kinds ?? const {},
        tags = tags ?? const {} {
    // IDs are either regular (64 character) or replaceable and match its regexp
    if (ids != null &&
        ids.any((i) => i.length != 64 && !kReplaceableRegexp.hasMatch(i))) {
      throw UnsupportedError('Bad ids input: $ids');
    }
    final authorsHex = authors?.map(Profile.hexFromNpub);
    if (authorsHex != null && authorsHex.any((a) => a.length != 64)) {
      throw UnsupportedError('Bad authors input: $authors');
    }
    this.subscriptionId = subscriptionId ?? 'sub-${_random.nextInt(999999)}';
  }

  factory RequestFilter.fromMap(Map<String, dynamic> map) {
    return RequestFilter(
      ids: {...?map['ids']},
      kinds: {...?map['kinds']},
      authors: {...?map['authors']},
      tags: {
        for (final e in map.entries)
          if (e.key.startsWith('#')) e.key: {...e.value}
      },
      search: map['search'],
      since: map['since'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['since'] * 1000)
          : null,
      until: map['until'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['until'] * 1000)
          : null,
      limit: map['limit'],
    );
  }

  factory RequestFilter.fromReplaceableEvent(String addressableId) {
    final [kind, author, ...rest] = addressableId.split(':');
    var req = RequestFilter(
      kinds: {int.parse(kind)},
      authors: {author},
    );
    if (rest.isNotEmpty && rest.first.isNotEmpty) {
      req = req.copyWith(tags: {
        '#d': {rest.first}
      });
    }
    return req;
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

  RequestFilter copyWith({
    Set<String>? ids,
    Set<String>? authors,
    Set<int>? kinds,
    Map<String, Set<String>>? tags,
    String? search,
    DateTime? since,
    DateTime? until,
    int? limit,
    int? queryLimit,
    bool? remote,
  }) {
    return RequestFilter(
      ids: ids ?? this.ids,
      authors: authors ?? this.authors,
      kinds: kinds ?? this.kinds,
      tags: tags ?? this.tags,
      search: search ?? this.search,
      since: since ?? this.since,
      until: until ?? this.until,
      limit: limit ?? this.limit,
      // Extra arguments
      subscriptionId: subscriptionId,
      queryLimit: queryLimit,
      remote: remote ?? this.remote,
      on: on,
      restrictToRelays: restrictToRelays,
      restrictToSubscription: restrictToSubscription,
      where: where,
      and: and,
    );
  }

  int get hash => fastHashString(toString());

  @override
  List<Object?> get props =>
      [ids, kinds, authors, tags, search, since, until, limit];

  @override
  String toString() {
    return toMap().toString();
  }
}

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

final kReplaceableRegexp = RegExp(r'(\d+):([0-9a-f]{64}):(.*)');

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

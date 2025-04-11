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
  final bool storageOnly;

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
    this.storageOnly = false,
    this.on,
    this.restrictToRelays = false,
    this.restrictToSubscription = false,
    this.where,
    this.and,
    Set<String>? relays,
  })  : ids = ids ?? const {},
        authors = authors ?? const {},
        kinds = kinds ?? const {},
        tags = tags ?? const {} {
    if (ids != null && ids.any((i) => i.length != 64)) {
      throw UnsupportedError('Bad ids input: $ids');
    }
    final authorsHex =
        authors?.map((a) => a.startsWith('npub') ? Profile.hexFromNpub(a) : a);
    if (authorsHex != null && authorsHex.any((a) => a.length != 64)) {
      throw UnsupportedError('Bad authors input: $authors');
    }
    this.subscriptionId = subscriptionId ?? 'sub-${_random.nextInt(999999)}';
  }

  factory RequestFilter.fromReplaceableEvents(Set<String> addressableIds) {
    RequestFilter? req;
    for (final addressableId in addressableIds) {
      final [kind, author, _] = addressableId.split(':');
      if (req == null) {
        req = RequestFilter(
          kinds: {int.parse(kind)},
          authors: {author},
        );
      } else {
        req = req.merge(RequestFilter(
          kinds: {int.parse(kind)},
          authors: {author},
        ))!;
      }
    }
    return req ?? RequestFilter();
  }

  RequestFilter? merge(RequestFilter req) {
    if (_equality.equals(kinds, req.kinds)) {
      return RequestFilter(
        authors: {...authors, ...req.authors},
      );
    }
    return null;
  }

  static final _equality = DeepCollectionEquality();

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
      Set<int>? kinds,
      Set<String>? authors,
      Map<String, Set<String>>? tags,
      DateTime? since,
      DateTime? until,
      int? limit,
      String? search,
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
      // Extra arguments
      subscriptionId: subscriptionId,
      queryLimit: queryLimit,
      storageOnly: storageOnly ?? this.storageOnly,
      on: on,
      restrictToRelays: restrictToRelays,
      restrictToSubscription: restrictToSubscription,
      where: where,
      and: and,
    );
  }

  int get hash => fastHashString(toString());

  @override
  List<Object?> get props => [toMap()];

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

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

import '../core/model.dart';
import '../core/types.dart';
import '../utils/utils.dart';
import '../utils/extensions.dart';
import 'request.dart';

final _kReplaceableRegexp = RegExp(r'(\d+):([0-9a-f]{64}):(.*)');

/// Nostr wire filter with optional client-side callbacks.
///
/// The wire-protocol fields (ids, kinds, authors, tags, since, until, limit, search)
/// are serializable. The client-side fields (where, and, schemaFilter) are kept
/// here temporarily for backward compatibility during the transition.
class RequestFilter<E extends Model<dynamic>> extends Equatable {
  final Set<String> ids;
  final Set<int> kinds;
  final Set<String> authors;
  final Map<String, Set<String>> tags;
  final DateTime? since;
  final DateTime? until;
  final int? limit;
  final String? search;

  /// Client-side post-query filter.
  final WhereFunction where;

  /// Relationship watch callback.
  final AndFunction and;

  /// Schema filter applied before model construction.
  final SchemaFilter? schemaFilter;

  RequestFilter({
    Set<String>? ids,
    Set<int>? kinds,
    Set<String>? authors,
    Map<String, Set<String>>? tags,
    this.since,
    this.until,
    this.limit,
    this.search,
    this.where,
    this.and,
    this.schemaFilter,
  })  : ids = ids ?? const {},
        authors = authors ?? const {},
        kinds = kinds ??
            (Model.isModelOfDynamic<E>()
                ? const {}
                : {Model.kindFor<E>()}),
        tags = tags == null
            ? const {}
            : {
                for (final e in tags.entries)
                  e.key.startsWith('#') ? e.key : '#${e.key}': e.value,
              } {
    if (ids != null &&
        ids.any((i) => i.length != 64 && !_kReplaceableRegexp.hasMatch(i))) {
      throw Exception('Bad ids input: $ids');
    }
    final authorsHex = authors?.map(Utils.decodeShareableToString);
    if (authorsHex != null && authorsHex.any((a) => a.length != 64)) {
      throw Exception('Bad authors input: $authors');
    }
  }

  factory RequestFilter.fromMap(Map<String, dynamic> map) {
    return RequestFilter<E>(
      ids: {...?map['ids']},
      kinds: Model.isModelOfDynamic<E>()
          ? {...?map['kinds']}
          : {Model.kindFor<E>()},
      authors: {...?map['authors']},
      tags: {
        for (final e in map.entries)
          if (e.key.startsWith('#')) e.key: {...e.value},
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

  Map<String, dynamic> toMap() {
    return {
      if (ids.isNotEmpty) 'ids': ids.sorted(),
      if (kinds.isNotEmpty) 'kinds': kinds.sorted((i, j) => i.compareTo(j)),
      if (authors.isNotEmpty) 'authors': authors.sorted(),
      for (final e in tags.entries.sortedBy((e) => e.key))
        if (e.value.isNotEmpty) e.key: e.value.sorted(),
      if (search != null) 'search': search,
      if (since != null) 'since': since!.toSeconds(),
      if (until != null) 'until': until!.toSeconds(),
      if (limit != null) 'limit': limit,
    };
  }

  RequestFilter<E> copyWith({
    Set<String>? ids,
    Set<String>? authors,
    Set<int>? kinds,
    Map<String, Set<String>>? tags,
    String? search,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) {
    return RequestFilter(
      ids: ids ?? this.ids,
      authors: authors ?? this.authors,
      kinds: kinds ?? this.kinds,
      tags: tags ?? this.tags,
      search: search ?? this.search,
      since: since?.millisecondsSinceEpoch == 0 ? null : since ?? this.since,
      until: until ?? this.until,
      limit: limit ?? this.limit,
      where: where,
      and: and,
      schemaFilter: schemaFilter,
    );
  }

  Request<E> toRequest({String? subscriptionPrefix}) =>
      Request([this], subscriptionPrefix: subscriptionPrefix);

  @override
  List<Object?> get props => [
        ids,
        kinds,
        authors,
        tags,
        search,
        since,
        until,
        limit,
      ];

  @override
  String toString() => toMap().toString();

  // Static merge methods

  /// Merges multiple request filters into same or fewer amount of filters.
  static List<RequestFilter> mergeMultiple(List<RequestFilter> filters) {
    if (filters.length <= 1) {
      return List.from(filters);
    }

    List<RequestFilter> currentFilters = List.from(filters);
    bool changed = true;

    while (changed) {
      changed = false;
      List<RequestFilter> nextFilters = [];
      List<bool> merged = List.filled(currentFilters.length, false);

      for (int i = 0; i < currentFilters.length; i++) {
        if (merged[i]) continue;

        RequestFilter accumulator = currentFilters[i];

        for (int j = i + 1; j < currentFilters.length; j++) {
          if (merged[j]) continue;

          List<RequestFilter> mergeResult = merge(
            accumulator,
            currentFilters[j],
          );

          if (mergeResult.length == 1) {
            accumulator = mergeResult[0];
            merged[j] = true;
            changed = true;
          }
        }
        nextFilters.add(accumulator);
        merged[i] = true;
      }

      currentFilters = nextFilters;
    }

    return currentFilters.cast();
  }

  static List<RequestFilter> merge(RequestFilter req1, RequestFilter req2) {
    final map1 = req1.toMap();
    final map2 = req2.toMap();
    final result = _merge(map1, map2);
    return (result != null ? [result] : [map1, map2])
        .map(RequestFilter.fromMap)
        .toList();
  }
}

extension RequestFilterIterableExt<E extends Model<dynamic>>
    on Iterable<RequestFilter<E>> {
  Request<E> toRequest({String? subscriptionPrefix}) =>
      Request<E>(toList(), subscriptionPrefix: subscriptionPrefix);
}

// Internal merge logic

final _eq = DeepCollectionEquality();

Map<String, dynamic>? _merge(
    Map<String, dynamic> f1, Map<String, dynamic> f2) {
  final Set<String> allKeys = {...f1.keys, ...f2.keys};
  final Set<String> arrayKeys = {
    'ids',
    'authors',
    'kinds',
    ...allKeys.where((k) => k.startsWith('#')),
  };

  Set<String> scalarKeys = {};

  for (final key in allKeys) {
    if (arrayKeys.contains(key)) {
      if (f1[key] == null || f2[key] == null) {
        return null;
      }
      if (!_eq.equals(f1[key], f2[key])) scalarKeys.add(key);
    } else {
      scalarKeys.add(key);
    }
  }

  if (scalarKeys.contains('search')) {
    return null;
  }

  final scalarArrayKeys = scalarKeys.intersection(arrayKeys);
  if (scalarArrayKeys.length > 1) {
    return null;
  }

  Map<String, int?> intValues = {};

  if (scalarKeys.contains('limit')) {
    final limit1 = f1['limit'] as num? ?? double.infinity;
    final limit2 = f2['limit'] as num? ?? double.infinity;
    if (scalarKeys.contains('ids')) {
      if (f1['ids'].length > limit1 || f2['ids'].length > limit2) {
        return null;
      }
    } else if (scalarKeys.length > 1) {
      return null;
    } else {
      final maxLimit = math.max(limit1, limit2);
      intValues['limit'] =
          maxLimit == double.infinity ? null : maxLimit.toInt();
    }
  }

  if (scalarKeys.contains('since') || scalarKeys.contains('until')) {
    final num f1Since = f1['since'] ?? 0;
    final num f1Until = f1['until'] ?? double.infinity;
    final num f2Since = f2['since'] ?? 0;
    final num f2Until = f2['until'] ?? double.infinity;

    if (scalarArrayKeys.isNotEmpty &&
        (f1Since != f2Since || f1Until != f2Until)) {
      return null;
    }

    if (f1Since <= f2Until && f2Since <= f1Until) {
      final sinceNum = math.min(f1Since, f2Since);
      intValues['since'] = sinceNum == 0 ? null : sinceNum.toInt();
      final untilNum = math.max(f1Until, f2Until);
      intValues['until'] =
          untilNum == double.infinity ? null : untilNum.toInt();
    } else {
      return null;
    }
  }

  final scalarArrayKey = scalarKeys.intersection(arrayKeys).firstOrNull;

  return {
    for (final k in arrayKeys)
      k: scalarArrayKey == k ? <dynamic>{...?f1[k], ...?f2[k]} : f1[k],
    ...intValues,
    if (f1.containsKey('search')) 'search': f1['search'].toString(),
  };
}

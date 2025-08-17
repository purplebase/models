part of models;

/// A request for fetching Nostr events with automatic relationship loading.
///
/// Requests define what data to fetch and how to handle relationships between
/// models. They can be executed to retrieve data from storage or relays.
///
/// Example usage:
/// ```dart
/// final request = RequestFilter<Note>(
///   authors: {'pubkey1', 'pubkey2'},
///   limit: 50,
/// ).toRequest();
///
/// final notes = await storage.query(request);
/// ```
class Request<E extends Model<dynamic>> with EquatableMixin {
  static final _random = Random();

  final List<RequestFilter<E>> filters;

  /// Provide a specific subscription ID
  late final String subscriptionId;

  Request(this.filters, {String? subscriptionId}) {
    this.subscriptionId = subscriptionId ?? 'sub-${_random.nextInt(999999)}';
  }

  factory Request.fromIds(Iterable<String> ids) {
    final regularIds = <String>{};
    final filters = <RequestFilter<E>>[];

    for (final id in ids) {
      if (!id.contains(':')) {
        regularIds.add(id);
        continue;
      }
      final [kind, author, ...rest] = id.split(':');
      var filter = RequestFilter<E>(
        kinds: {int.parse(kind)},
        authors: {author},
      );
      if (rest.isNotEmpty && rest.first.isNotEmpty) {
        filter = filter.copyWith(
          tags: {
            '#d': {rest.first},
          },
        );
      }
      filters.add(filter);
    }
    if (regularIds.isNotEmpty) {
      filters.add(RequestFilter(ids: regularIds));
    }
    return Request(filters);
  }

  List<Map<String, dynamic>> toMaps() {
    return filters.map((f) => f.toMap()).toList();
  }

  @override
  List<Object?> get props => [filters];

  @override
  String toString() {
    return 'Req[${filters.join(', ')}]';
  }
}

/// A nostr request filter, with additional arguments for querying a [StorageNotifier]
class RequestFilter<E extends Model<dynamic>> extends Equatable {
  final Set<String> ids;
  final Set<int> kinds;
  final Set<String> authors;
  final Map<String, Set<String>> tags;
  final DateTime? since;
  final DateTime? until;
  final int? limit;
  final String? search;

  /// Provide additional post-query filtering in Dart
  final WhereFunction where; // Important: do not pass <E>

  /// Watch relationships
  final AndFunction and; // Important: do not pass <E>

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
  }) : ids = ids ?? const {},
       authors = authors ?? const {},
       kinds =
           kinds ?? (_isModelOfDynamic<E>() ? const {} : {Model._kindFor<E>()}),
       tags = tags == null
           ? const {}
           : {
               for (final e in tags.entries)
                 e.key.startsWith('#') ? e.key : '#${e.key}': e.value,
             } {
    // IDs are either regular (64 character) or replaceable and match its regexp
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
      kinds: _isModelOfDynamic<E>()
          ? {...?map['kinds']}
          : {Model._kindFor<E>()},
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

  static bool _isModelOfDynamic<E extends Model<dynamic>>() =>
      <Model<dynamic>>[] is List<E>;

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
    );
  }

  Request<E> toRequest() => Request([this]);

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

  // Static

  /// Merges multiple requests into same or fewer amount of requests,
  /// with equivalent results from relays, which can help save in
  /// bandwidth and processing
  static List<RequestFilter> mergeMultiple(List<RequestFilter> filters) {
    if (filters.length <= 1) {
      return List.from(filters); // Return a copy
    }

    List<RequestFilter> currentFilters = List.from(filters);
    bool changed = true; // Start assuming changes might happen

    while (changed) {
      changed = false;
      List<RequestFilter> nextFilters = [];
      List<bool> merged = List.filled(
        currentFilters.length,
        false,
      ); // Track consumed filters

      for (int i = 0; i < currentFilters.length; i++) {
        if (merged[i]) continue; // Already consumed

        RequestFilter accumulator = currentFilters[i];

        // Try merging with subsequent filters
        for (int j = i + 1; j < currentFilters.length; j++) {
          if (merged[j]) continue; // Already consumed

          List<RequestFilter> mergeResult = merge(
            accumulator,
            currentFilters[j],
          );

          if (mergeResult.length == 1) {
            // Merge succeeded
            accumulator = mergeResult[0]; // Update accumulator
            merged[j] = true; // Mark j as consumed
            changed = true; // A merge happened
          }
        }
        nextFilters.add(
          accumulator,
        ); // Add the final result for this accumulator
        merged[i] = true; // Mark i as processed (placed in nextFilters)
      }

      currentFilters = nextFilters; // Prepare for next iteration
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

final _kReplaceableRegexp = RegExp(r'(\d+):([0-9a-f]{64}):(.*)');

extension RequestFilterIterableExt<E extends Model<dynamic>>
    on Iterable<RequestFilter<E>> {
  Request<E> toRequest() => Request<E>(toList());
}

Map<String, dynamic>? _merge(Map<String, dynamic> f1, Map<String, dynamic> f2) {
  final Set<String> allKeys = {...f1.keys, ...f2.keys};
  final Set<String> arrayKeys = {
    'ids',
    'authors',
    'kinds',
    ...allKeys.where((k) => k.startsWith('#')),
  };

  Set<String> differingKeys = {};

  // Check for differing keys
  for (final key in allKeys) {
    if (arrayKeys.contains(key)) {
      if (f1[key] == null || f2[key] == null) {
        // If one of the arrays is not present, its unbounded, can't merge
        return null;
      }
      if (!_eq.equals(f1[key], f2[key])) differingKeys.add(key);
    } else {
      // Just their presence means its differing
      differingKeys.add(key);
    }
  }

  if (differingKeys.contains('search')) {
    return null;
  }

  final differingArrayKeys = differingKeys.intersection(arrayKeys);
  if (differingArrayKeys.length > 1) {
    return null;
  }

  Map<String, int?> intValues = {};

  // If we have limit and another differing key
  if (differingKeys.contains('limit')) {
    final limit1 = f1['limit'] as num? ?? double.infinity;
    final limit2 = f2['limit'] as num? ?? double.infinity;
    if (differingKeys.contains('ids')) {
      if (f1['ids'].length > limit1 || f2['ids'].length > limit2) {
        return null;
      }
    } else if (differingKeys.length > 1) {
      return null;
    } else {
      // We only have limit as differing
      final maxLimit = max(limit1, limit2);
      intValues['limit'] = maxLimit == double.infinity
          ? null
          : maxLimit.toInt();
    }
  }

  if (differingKeys.contains('since') || differingKeys.contains('until')) {
    final num f1Since = f1['since'] ?? 0;
    final num f1Until = f1['until'] ?? double.infinity;
    final num f2Since = f2['since'] ?? 0;
    final num f2Until = f2['until'] ?? double.infinity;

    // Only way we keep going with differingArrayKeys is if since/until are the same
    if (differingArrayKeys.isNotEmpty &&
        (f1Since != f2Since || f1Until != f2Until)) {
      return null;
    }

    if (f1Since <= f2Until && f2Since <= f1Until) {
      final sinceNum = min(f1Since, f2Since);
      intValues['since'] = sinceNum == 0 ? null : sinceNum.toInt();
      final untilNum = max(f1Until, f2Until);
      intValues['until'] = untilNum == double.infinity
          ? null
          : untilNum.toInt();
    } else {
      return null;
    }
  }

  final differingArrayKey = differingKeys.intersection(arrayKeys).firstOrNull;

  return {
    for (final k in arrayKeys)
      // Merge differing keys, others take from f1
      k: differingArrayKey == k ? <dynamic>{...?f1[k], ...?f2[k]} : f1[k],
    ...intValues,
    if (f1.containsKey('search')) 'search': f1['search'].toString(),
  };
}

final _eq = DeepCollectionEquality();

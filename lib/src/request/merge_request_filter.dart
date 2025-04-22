part of models;

/// Merges multiple requests into same or fewer amount of requests,
/// with equivalent results from relays, which can help save in
/// bandwidth and processing
List<RequestFilter<E>> mergeMultipleRequests<E extends Model<dynamic>>(
    List<RequestFilter<E>> filters) {
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

        List<RequestFilter> mergeResult = mergeRequests(
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
      nextFilters.add(accumulator); // Add the final result for this accumulator
      merged[i] = true; // Mark i as processed (placed in nextFilters)
    }

    currentFilters = nextFilters; // Prepare for next iteration
  }

  return currentFilters.cast();
}

List<RequestFilter> mergeRequests(RequestFilter req1, RequestFilter req2) {
  final map1 = req1.toMap();
  final map2 = req2.toMap();
  final result = _merge(map1, map2);
  return (result != null ? [result] : [map1, map2])
      .map(RequestFilter.fromMap)
      .toList();
}

Map<String, dynamic>? _merge(
  Map<String, dynamic> f1,
  Map<String, dynamic> f2,
) {
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
      intValues['limit'] =
          maxLimit == double.infinity ? null : maxLimit.toInt();
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
      intValues['until'] =
          untilNum == double.infinity ? null : untilNum.toInt();
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

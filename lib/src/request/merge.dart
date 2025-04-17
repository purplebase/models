part of models;

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

bool canMerge(Map<String, dynamic> filter1, Map<String, dynamic> filter2) {
  // Check if Set properties and search are present in both filters or absent in both
  for (final key in {
    'search',
    'ids',
    'authors',
    'kinds',
    ...filter1.keys.where((k) => k.startsWith('#')),
    ...filter2.keys.where((k) => k.startsWith('#')),
  }) {
    if (filter1.containsKey(key) != filter2.containsKey(key)) {
      return false; // Both must have the property or neither
    }
  }

  // Track differences excluding limit since it has special handling
  int diffCount = 0;
  String diffProperty = '';
  bool limitPresent = false;

  // Check limit separately
  if (filter1.containsKey('limit') || filter2.containsKey('limit')) {
    limitPresent = true;
  }

  // Check search
  if (filter1.containsKey('search') && filter1['search'] != filter2['search']) {
    diffCount++;
    diffProperty = 'search';
  }

  // Check since and until - we'll handle their special case later
  bool sinceDiffers = false;
  bool untilDiffers = false;

  if (filter1['since'] != filter2['since']) {
    sinceDiffers = true;
    diffCount++;
    diffProperty = 'since';
  }

  if (filter1['until'] != filter2['until']) {
    untilDiffers = true;
    diffCount++;
    diffProperty = 'until';
  }

  // Check Set properties
  for (final key in {
    'ids',
    'authors',
    'kinds',
    ...filter1.keys.where((k) => k.startsWith('#')),
  }) {
    if (filter1.containsKey(key) && !_eq.equals(filter1[key], filter2[key])) {
      diffCount++;
      diffProperty = key;
    }
  }

  // Apply the rules
  if (diffCount == 0) {
    return true; // Identical filters can be merged (even if limit differs)
  }

  // If search differs, not mergeable
  if (diffProperty == 'search') {
    return false;
  }

  // Special case for since/until
  if ((diffProperty == 'since' || diffProperty == 'until') ||
      (sinceDiffers && untilDiffers && diffCount == 2)) {
    // Check if they form an overlapping or contiguous time block
    // Two time ranges overlap if the start of one is before the end of the other
    return (filter1['since'] ?? 0) <= (filter2['until'] ?? double.infinity) &&
        (filter2['since'] ?? 0) <= (filter1['until'] ?? double.infinity);
  }

  // If more than one property differs (excluding limit), not mergeable
  if (diffCount > 1) {
    return false;
  }

  // If limit is present and any other property differs, not mergeable
  if (limitPresent && diffCount > 0) {
    return false;
  }

  // If we've come this far, the filters differ in one property (which isn't search or limit), which is mergeable
  return true;
}

final _eq = DeepCollectionEquality();

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

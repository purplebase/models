part of models;

List<RequestFilter> mergeRequests(RequestFilter req1, RequestFilter req2) {
  return _merge(req1.toMap(), req2.toMap()).map(RequestFilter.fromMap).toList();
}

List<Map<String, dynamic>> _merge(
  Map<String, dynamic> filter1,
  Map<String, dynamic> filter2,
) {
  Map<String, dynamic> f1 = Map.from(filter1);
  Map<String, dynamic> f2 = Map.from(filter2);

  final Set<String> allKeys = {...f1.keys, ...f2.keys};
  final Set<String> arrayKeys = {
    'ids',
    'authors',
    'kinds',
    ...allKeys.where((k) => k.startsWith('#')),
  };

  List<String> differingKeys = [];
  bool presenceMismatch = false;

  // Check for differing keys and inconsistent presence
  for (final key in allKeys) {
    bool f1Has = f1.containsKey(key);
    bool f2Has = f2.containsKey(key);

    if (f1Has != f2Has) {
      // Allow limit to be missing in one
      if (key != 'limit') {
        presenceMismatch = true;
        break;
      }
    } else if (f1Has) {
      // Both have the key
      if (key == 'search') {
        if (f1[key] != f2[key]) differingKeys.add(key);
      } else if (arrayKeys.contains(key)) {
        if (!_eq.equals(f1[key], f2[key])) differingKeys.add(key);
      } else if (key == 'since' || key == 'until') {
        if (f1[key] != f2[key]) differingKeys.add(key);
      }
      // Ignore 'limit' difference during this initial check
    }
  }

  if (presenceMismatch) return [f1, f2];
  if (differingKeys.contains('search')) return [f1, f2];

  List<String> nonLimitDiffs =
      differingKeys.where((k) => k != 'limit').toList();
  bool limitPresent = f1.containsKey('limit') || f2.containsKey('limit');

  // --- Handle Special 'ids' Merging ---
  // Merge if only 'ids' differs, or if 'ids' and 'limit' differ.
  bool idsDiffer = differingKeys.contains('ids');
  bool onlyIdsOrIdsAndLimitDiffer =
      nonLimitDiffs.length == (idsDiffer ? 1 : 0) && idsDiffer;

  if (idsDiffer && onlyIdsOrIdsAndLimitDiffer) {
    Map<String, dynamic> merged = {};
    // Copy non-ids, non-limit keys from f1 (they must match f2)
    f1.forEach((key, value) {
      if (key != 'ids' && key != 'limit') {
        merged[key] = value;
      }
    });

    final mergedIds =
        {...(f1['ids'] as List? ?? []), ...(f2['ids'] as List? ?? [])}.toList();
    merged['ids'] = mergedIds;
    merged['limit'] = mergedIds.length; // Limit is count of merged IDs
    return [merged];
  }

  // --- General Merge Logic ---

  // Non-mergeable: Limit present AND any non-limit difference exists (excluding the handled 'ids' case)
  if (limitPresent && nonLimitDiffs.isNotEmpty) {
    return [f1, f2];
  }

  // Non-mergeable: More than one non-limit difference, unless it's just since/until
  bool onlySinceUntilDiff = nonLimitDiffs.length <= 2 &&
      nonLimitDiffs.every((k) => k == 'since' || k == 'until');

  if (nonLimitDiffs.length > 1 && !onlySinceUntilDiff) {
    return [f1, f2];
  }

  // --- Mergeable Cases ---
  Map<String, dynamic> merged = Map.from(f1); // Base for merging

  // Case 1: Identical (nonLimitDiffs.isEmpty) - Handle limit based on tests
  if (nonLimitDiffs.isEmpty) {
    dynamic l1 = f1['limit'];
    dynamic l2 = f2['limit'];
    if (l1 != null && l2 != null) {
      merged['limit'] = max(l1 as num, l2 as num); // Max limit if both present
    } else if (l1 != null || l2 != null) {
      merged.remove('limit'); // No limit if only one present
    } else {
      merged.remove('limit'); // Ensure no limit if neither present
    }
    return [merged];
  }

  // Case 2: Only Since/Until differ
  if (onlySinceUntilDiff) {
    dynamic f1Since = f1['since'];
    dynamic f2Since = f2['since'];
    dynamic f1Until = f1['until'];
    dynamic f2Until = f2['until'];

    // Check for overlap/contiguity required by canMerge
    num f1SinceVal = (f1Since is num ? f1Since : 0);
    num f1UntilVal = (f1Until is num ? f1Until : double.infinity);
    num f2SinceVal = (f2Since is num ? f2Since : 0);
    num f2UntilVal = (f2Until is num ? f2Until : double.infinity);

    if (f1SinceVal <= f2UntilVal && f2SinceVal <= f1UntilVal) {
      // Merge since (min non-null)
      dynamic mergedSince;
      if (f1Since != null && f2Since != null) {
        mergedSince = min(f1Since as num, f2Since as num);
      } else {
        mergedSince =
            f1Since ?? f2Since; // Take the non-null one, or null if both null
      }
      if (mergedSince != null) {
        merged['since'] = mergedSince;
      } else {
        merged.remove('since');
      }

      // Merge until (max non-null)
      dynamic mergedUntil;
      if (f1Until != null && f2Until != null) {
        mergedUntil = max(f1Until as num, f2Until as num);
      } else {
        mergedUntil =
            f1Until ?? f2Until; // Take the non-null one, or null if both null
      }
      if (mergedUntil != null) {
        merged['until'] = mergedUntil;
      } else {
        merged.remove('until');
      }

      merged.remove('limit'); // Cannot have limit if since/until differ
      return [merged];
    } else {
      // No overlap -> cannot merge
      return [f1, f2];
    }
  }

  // Case 3: Single differing array key (and not 'ids', which was handled earlier)
  if (nonLimitDiffs.length == 1 && arrayKeys.contains(nonLimitDiffs[0])) {
    String key = nonLimitDiffs[0];
    // Ensure keys exist before accessing (should be guaranteed by presence check)
    List list1 = f1[key] as List? ?? [];
    List list2 = f2[key] as List? ?? [];
    merged[key] =
        {...list1, ...list2}.toList(); // Merge using Set for uniqueness
    merged.remove('limit'); // Cannot have limit if arrays differ
    return [merged];
  }

  // Fallback: If none of the mergeable conditions were met.
  return [f1, f2];
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

List<RequestFilter<E>> mergeMultipleRequests<E extends Event<dynamic>>(
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

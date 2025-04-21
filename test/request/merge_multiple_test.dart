import 'package:models/models.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  final generate64Hex = Utils.generateRandomHex64;

  test("empty array returns empty array", () {
    final filters = <RequestFilter>[];
    final expected = <RequestFilter>[];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  test("single filter returns that filter", () {
    final filters = [
      RequestFilter(
        authors: {nielPubkey},
      ),
    ];
    final expected = [
      RequestFilter(
        authors: {nielPubkey},
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  test("two filters - same as regular merge", () {
    final filters = [
      RequestFilter(
        authors: {nielPubkey},
      ),
      RequestFilter(
        authors: {franzapPubkey},
      ),
    ];
    final expected = [
      RequestFilter(
        authors: {nielPubkey, franzapPubkey},
      ),
    ]; // Assuming merge logic combines lists
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  // IDs-only filter tests
  test("all ids-only filters are merged into one", () {
    final [id1, id2, id3, id4, id5, id6] = [
      generate64Hex(),
      generate64Hex(),
      generate64Hex(),
      generate64Hex(),
      generate64Hex(),
      generate64Hex()
    ];
    final filters = [
      RequestFilter(
        ids: {id1, id2},
        limit: 1,
      ),
      RequestFilter(
        ids: {id3, id4},
        limit: 10,
      ),
      RequestFilter(
        ids: {id5, id6},
      ),
    ];
    final expected = [
      RequestFilter(
        ids: {id1, id2},
        limit: 1,
      ),
      RequestFilter(
        ids: {id3, id4, id5, id6},
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  test("ids-only filters are merged separately from other filters", () {
    final [
      id1,
      id2,
      id3,
      id4
    ] = [generate64Hex(), generate64Hex(), generate64Hex(), generate64Hex()];
    final filters = [
      RequestFilter(
        ids: {id1, id2},
        limit: 5,
      ),
      RequestFilter(
        authors: {nielPubkey},
      ),
      RequestFilter(
        ids: {id3, id4},
      ),
      RequestFilter(
        authors: {franzapPubkey},
      ),
    ];
    final expected = [
      RequestFilter(
        ids: {id1, id2, id3, id4},
      ),
      RequestFilter(
        authors: {nielPubkey, franzapPubkey},
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  // Property signature grouping tests
  test("filters with different properties stay separate", () {
    final filters = [
      RequestFilter(
        authors: {nielPubkey},
      ),
      RequestFilter(
        kinds: {1},
      ),
      RequestFilter(
        tags: {
          '#e': {'x'}
        },
      ),
    ];
    final expected = [
      RequestFilter(
        authors: {nielPubkey},
      ),
      RequestFilter(
        kinds: {1},
      ),
      RequestFilter(
        tags: {
          '#e': {'x'}
        },
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  test("filters with same properties are grouped and merged", () {
    final filters = [
      RequestFilter(
        authors: {nielPubkey},
      ),
      RequestFilter(
        authors: {franzapPubkey},
      ),
      RequestFilter(
        kinds: {1},
      ),
      RequestFilter(
        kinds: {2},
      ),
    ];
    final expected = [
      RequestFilter(
        authors: {nielPubkey, franzapPubkey},
      ),
      RequestFilter(
        kinds: {1, 2},
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  test("complex property grouping", () {
    final filters = [
      RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
      ),
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {2},
      ),
      RequestFilter(
        authors: {verbirichaPubkey},
        kinds: {1},
      ),
      RequestFilter(
        tags: {
          '#e': {'x'}
        },
      ),
      RequestFilter(
        tags: {
          '#e': {'y'}
        },
      ),
    ];
    final expected = [
      RequestFilter(
        authors: {nielPubkey, verbirichaPubkey},
        kinds: {1},
      ),
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {2},
      ),
      RequestFilter(
        tags: {
          '#e': {'x', 'y'}
        },
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  // Limit prioritization tests
  test("filters without limit are prioritized for merging", () {
    final filters = [
      RequestFilter(
        authors: {nielPubkey},
        limit: 10,
      ),
      RequestFilter(
        authors: {franzapPubkey},
        limit: 20,
      ),
      RequestFilter(
        authors: {verbirichaPubkey},
      ),
      RequestFilter(
        authors: {generate64Hex()}, // Using generate64Hex for 'd'
      ),
    ];
    // Order might differ slightly based on implementation, but content should match
    final expected = [
      RequestFilter(
        authors: {
          verbirichaPubkey,
          filters[3].authors.first
        }, // Reference generated author 'd'
      ),
      RequestFilter(
        authors: {nielPubkey},
        limit: 10,
      ),
      RequestFilter(
        authors: {franzapPubkey},
        limit: 20,
      ),
    ];
    final result = mergeMultipleRequests(filters);
    // Need custom matcher or manual sort/compare due to generated author
    expect(result.length, expected.length);
    expect(result, containsAll(expected));
  });

  test("filters with limit that can't merge remain separate", () {
    final filters = [
      RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
        limit: 10,
      ),
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {1},
        limit: 20,
      ),
      RequestFilter(
        authors: {verbirichaPubkey},
        kinds: {2},
        limit: 30,
      ),
    ];
    final expected = [
      RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
        limit: 10,
      ),
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {1},
        limit: 20,
      ),
      RequestFilter(
        authors: {verbirichaPubkey},
        kinds: {2},
        limit: 30,
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  // Iterative merging tests
  test(
    "iterative merging - filters that couldn't merge initially can merge after other merges",
    () {
      final filters = [
        RequestFilter(
          authors: {nielPubkey},
          tags: {
            '#e': {'x'}
          },
        ),
        RequestFilter(
          authors: {franzapPubkey},
          tags: {
            '#e': {'x'}
          },
        ),
        RequestFilter(
          authors: {franzapPubkey},
          tags: {
            '#e': {'y'}
          },
        ),
      ];
      final expected = [
        RequestFilter(
          authors: {nielPubkey, franzapPubkey},
          tags: {
            '#e': {'x'}
          },
        ),
        RequestFilter(
          authors: {franzapPubkey},
          tags: {
            '#e': {'y'}
          },
        ),
      ];
      final result = mergeMultipleRequests(filters);
      expect(result, unorderedEquals(expected));
    },
  );

  test("complex iterative merging example", () {
    final filters = [
      RequestFilter(
        authors: {nielPubkey},
        kinds: {1, 2},
      ),
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {1, 2},
      ),
      RequestFilter(
        authors: {verbirichaPubkey},
        kinds: {1, 2},
      ),
      RequestFilter(
        authors: {nielPubkey, franzapPubkey},
        kinds: {3},
      ),
      RequestFilter(
        authors: {franzapPubkey, verbirichaPubkey},
        kinds: {4},
      ),
    ];
    final expected = [
      RequestFilter(
        authors: {nielPubkey, franzapPubkey, verbirichaPubkey},
        kinds: {1, 2},
      ),
      RequestFilter(
        authors: {nielPubkey, franzapPubkey},
        kinds: {3},
      ),
      RequestFilter(
        authors: {franzapPubkey, verbirichaPubkey},
        kinds: {4},
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  // Since/until handling tests
  // Assuming 'since' and 'until' values prevent merging if they differ,
  // unless one filter can fully contain the other's time range (based on merge logic, not mergeMultiple).
  test(
    "merges filters with different since values requires merge function logic (mergeMultiple won't merge)",
    () {
      final filters = [
        RequestFilter(
          authors: {nielPubkey},
          since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
        ),
        RequestFilter(
          authors: {franzapPubkey},
          since: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
        ),
        RequestFilter(
          authors: {verbirichaPubkey},
          since: DateTime.fromMillisecondsSinceEpoch(150 * 1000),
        ),
      ];
      // Since they differ, mergeMultiple wouldn't merge them on its own.
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
          since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
        ),
        RequestFilter(
          authors: {franzapPubkey},
          since: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
        ),
        RequestFilter(
          authors: {verbirichaPubkey},
          since: DateTime.fromMillisecondsSinceEpoch(150 * 1000),
        ),
      ];
      final result = mergeMultipleRequests(filters);
      expect(result, unorderedEquals(expected));
    },
  );

  test(
    "merges filters with different until values requires merge function logic (mergeMultiple won't merge)",
    () {
      final filters = [
        RequestFilter(
          authors: {nielPubkey},
          until: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
        ),
        RequestFilter(
          authors: {franzapPubkey},
          until: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
        ),
        RequestFilter(
          authors: {verbirichaPubkey},
          until: DateTime.fromMillisecondsSinceEpoch(150 * 1000),
        ),
      ];
      // Similar to 'since', assuming they don't merge if until differs.
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
          until: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
        ),
        RequestFilter(
          authors: {franzapPubkey},
          until: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
        ),
        RequestFilter(
          authors: {verbirichaPubkey},
          until: DateTime.fromMillisecondsSinceEpoch(150 * 1000),
        ),
      ];
      final result = mergeMultipleRequests(filters);
      expect(result, unorderedEquals(expected));
    },
  );

  test(
      "handles mix of since and until requires merge function logic (mergeMultiple won't merge)",
      () {
    final filters = [
      RequestFilter(
        authors: {nielPubkey},
        since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
      ),
      RequestFilter(
        authors: {franzapPubkey},
        until: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
      ),
      RequestFilter(
        authors: {verbirichaPubkey},
        since: DateTime.fromMillisecondsSinceEpoch(150 * 1000),
        until: DateTime.fromMillisecondsSinceEpoch(250 * 1000),
      ),
    ];
    // No merge based on authors/since/until mismatch
    final expected = [
      RequestFilter(
        authors: {nielPubkey},
        since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
      ),
      RequestFilter(
        authors: {franzapPubkey},
        until: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
      ),
      RequestFilter(
        authors: {verbirichaPubkey},
        since: DateTime.fromMillisecondsSinceEpoch(150 * 1000),
        until: DateTime.fromMillisecondsSinceEpoch(250 * 1000),
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  // Mixed property tests
  test("mix of all filter types", () {
    final [
      id1,
      id2,
      id3,
      id4
    ] = [generate64Hex(), generate64Hex(), generate64Hex(), generate64Hex()];
    final filters = [
      RequestFilter(
        ids: {id1, id2},
        limit: 5,
      ),
      RequestFilter(
        ids: {id3, id4},
      ),
      RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
        since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
      ),
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {1},
        until: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
      ),
      RequestFilter(
        authors: {verbirichaPubkey},
      ),
      RequestFilter(
        tags: {
          '#e': {'x'}
        },
      ),
      RequestFilter(
        tags: {
          '#e': {'y'}
        },
      ),
    ];
    final expected = [
      RequestFilter(
        ids: {id1, id2, id3, id4},
      ), // Merged IDs
      RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
        since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
      ), // Stays separate
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {1},
        until: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
      ), // Stays separate
      RequestFilter(
        authors: {verbirichaPubkey},
      ), // Stays separate
      RequestFilter(
        tags: {
          '#e': {'x', 'y'}
        },
      ), // Merged #e
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  // Differing array properties tests
  test("filters with more than one differing array property don't merge", () {
    final filters = [
      RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
        tags: {
          '#e': {'x'}
        },
      ),
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {2},
        tags: {
          '#e': {'x'}
        },
      ), // authors and kinds differ
    ];
    final expected = [
      RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
        tags: {
          '#e': {'x'}
        },
      ),
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {2},
        tags: {
          '#e': {'x'}
        },
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  test("filters with differing array property and no limit can merge", () {
    final authorZ = generate64Hex();
    final filters = [
      RequestFilter(
        authors: {authorZ},
        kinds: {2},
      ),
      RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
      ),
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {1},
      ),
      RequestFilter(
        authors: {verbirichaPubkey},
        kinds: {1},
      ),
      RequestFilter(
        authors: {nielPubkey},
        kinds: {2},
      ), // 'authors' differs but can merge within same 'kinds' group
    ];
    final expected = [
      // Group by 'kinds', then merge 'authors'
      RequestFilter(
        authors: {nielPubkey, franzapPubkey, verbirichaPubkey},
        kinds: {1},
      ),
      RequestFilter(
        authors: {authorZ, nielPubkey},
        kinds: {2},
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  test("filters with differing array property and limit can't merge", () {
    final filters = [
      RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
        limit: 10,
      ),
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {1},
        limit: 20,
      ), // 'authors' differs, 'limit' prevents merge
    ];
    final expected = [
      RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
        limit: 10,
      ),
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {1},
        limit: 20,
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  // Large test case
  test("large test with many filters", () {
    final [a1, a2, a3, b1, b2, c1, c3, id1, id2, id3, id4] =
        List.generate(11, (_) => generate64Hex());
    final filters = [
      RequestFilter(
        authors: {a1},
        kinds: {1},
      ),
      RequestFilter(
        authors: {a2},
        kinds: {1},
      ),
      RequestFilter(
        authors: {a3},
        kinds: {1},
      ),
      RequestFilter(
        authors: {a1},
        kinds: {2},
      ),
      RequestFilter(
        authors: {a2},
        kinds: {2},
      ),
      RequestFilter(
        ids: {id1, id2},
      ),
      RequestFilter(
        ids: {id3, id4},
      ),
      RequestFilter(
        tags: {
          '#e': {'t1'}
        },
      ),
      RequestFilter(
        tags: {
          '#e': {'t2'}
        },
      ),
      RequestFilter(
        tags: {
          '#e': {'t3'}
        },
      ),
      RequestFilter(
        authors: {b1},
        limit: 10,
      ), // Separate
      RequestFilter(
        authors: {b2},
        limit: 20,
      ), // Separate
      RequestFilter(
        authors: {c1},
        since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
      ),
      RequestFilter(
        authors: {c1},
        since: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
      ), // This will be separate due to different 'since'
      RequestFilter(
        authors: {c3},
        until: DateTime.fromMillisecondsSinceEpoch(300 * 1000),
      ),
    ];
    // Order might vary based on grouping/prioritization strategy
    final expected = [
      RequestFilter(
        authors: {a1, a2, a3},
        kinds: {1},
      ),
      RequestFilter(
        authors: {a1, a2},
        kinds: {2},
      ),
      RequestFilter(
        ids: {id1, id2, id3, id4},
      ),
      RequestFilter(
        tags: {
          '#e': {'t1', 't2', 't3'}
        },
      ),
      RequestFilter(
        authors: {c1},
        since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
      ),
      RequestFilter(
        authors: {c3},
        until: DateTime.fromMillisecondsSinceEpoch(300 * 1000),
      ),
      // Then limit filters
      RequestFilter(
        authors: {b1},
        limit: 10,
      ),
      RequestFilter(
        authors: {b2},
        limit: 20,
      ),
    ];

    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  // Order-independent tests
  test("results should be the same regardless of input order - case 1", () {
    final filters = [
      RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
      ),
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {1},
      ),
      RequestFilter(
        authors: {verbirichaPubkey},
        kinds: {2},
      ),
    ];
    final expected = [
      RequestFilter(
        authors: {nielPubkey, franzapPubkey},
        kinds: {1},
      ),
      RequestFilter(
        authors: {verbirichaPubkey},
        kinds: {2},
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  test("results should be the same regardless of input order - case 2", () {
    final filters = [
      RequestFilter(
        authors: {verbirichaPubkey},
        kinds: {2},
      ),
      RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
      ),
      RequestFilter(
        authors: {franzapPubkey},
        kinds: {1},
      ),
    ];
    // Output order might differ, but content must match. The helper `equals` handles standard Map/List comparison.
    final expected = [
      RequestFilter(
        authors: {nielPubkey, franzapPubkey},
        kinds: {1},
      ),
      RequestFilter(
        authors: {verbirichaPubkey},
        kinds: {2},
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });

  test("shit ton", () {
    final filters = [
      RequestFilter(
        kinds: {1},
        tags: {
          '#e': {'x'}
        },
      ),
      RequestFilter(
        kinds: {1},
        tags: {
          '#e': {'y'}
        },
      ),
      RequestFilter(
        kinds: {1},
        tags: {
          '#e': {'z'}
        },
      ),
    ];
    final expected = [
      RequestFilter(
        kinds: {1},
        tags: {
          '#e': {'x', 'y', 'z'}
        },
      ),
    ];
    final result = mergeMultipleRequests(filters);
    expect(result, unorderedEquals(expected));
  });
}

import 'package:models/models.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  final generate64Hex = Utils.generateRandomHex64;

  group('Merge pairs', () {
    // Test limits with identical filters
    test("identical filters except limit - bigger limit wins", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        limit: 10,
      );
      final filter2 = RequestFilter(
        authors: {nielPubkey},
        limit: 20,
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
          limit: 20,
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("identical filters - no limit wins over having limit", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        limit: 10,
      );
      final filter2 = RequestFilter(
        authors: {nielPubkey},
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    // Test ids-only filters
    test("ids-only filters - limits are added and ids are merged", () {
      final [
        id1,
        id2,
        id3,
        id4
      ] = [generate64Hex(), generate64Hex(), generate64Hex(), generate64Hex()];
      final filter1 = RequestFilter(
        ids: {id1, id2},
        limit: 10,
      );
      final filter2 = RequestFilter(
        ids: {id3, id4},
        limit: 20,
      );
      final expected = [
        RequestFilter(
          ids: {id1, id2, id3, id4},
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("ids-only filters - limits less than length and ids are not merged",
        () {
      final [
        id1,
        id2,
        id3,
        id4
      ] = [generate64Hex(), generate64Hex(), generate64Hex(), generate64Hex()];
      final filter1 = RequestFilter(
        ids: {id1, id2},
        limit: 1,
      );
      final filter2 = RequestFilter(
        ids: {id3, id4},
      );
      final expected = [
        RequestFilter(
          ids: {id1, id2},
          limit: 1,
        ),
        RequestFilter(
          ids: {id3, id4},
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
      // print(result);
    });

    test("ids-only filters - one without limit", () {
      final [
        id1,
        id2,
        id3,
        id4
      ] = [generate64Hex(), generate64Hex(), generate64Hex(), generate64Hex()];
      final filter1 = RequestFilter(
        ids: {id1, id2},
        limit: 10,
      );
      final filter2 = RequestFilter(
        ids: {id3, id4},
      );
      final expected = [
        RequestFilter(
          ids: {id1, id2, id3, id4},
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("ids-only filters - both without limit", () {
      final [
        id1,
        id2,
        id3,
        id4
      ] = [generate64Hex(), generate64Hex(), generate64Hex(), generate64Hex()];
      final filter1 = RequestFilter(
        ids: {id1, id2},
      );
      final filter2 = RequestFilter(
        ids: {id3, id4},
      );
      final expected = [
        RequestFilter(
          ids: {id1, id2, id3, id4},
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    // Test array merging
    test("merges authors arrays", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey, franzapPubkey},
      );
      final filter2 = RequestFilter(
        authors: {franzapPubkey, verbirichaPubkey},
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey, franzapPubkey, verbirichaPubkey},
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("merges kinds arrays", () {
      final filter1 = RequestFilter(
        kinds: {1, 2},
      );
      final filter2 = RequestFilter(
        kinds: {2, 3},
      );
      final expected = [
        RequestFilter(
          kinds: {1, 2, 3},
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    // Test since/until handling
    test("handles since (min) and until (max)", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
        until: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
      );
      final filter2 = RequestFilter(
        authors: {nielPubkey},
        since: DateTime.fromMillisecondsSinceEpoch(50 * 1000),
        until: DateTime.fromMillisecondsSinceEpoch(300 * 1000),
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
          since: DateTime.fromMillisecondsSinceEpoch(50 * 1000),
          until: DateTime.fromMillisecondsSinceEpoch(300 * 1000),
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test('handles since and until', () {
      final filter1 = RequestFilter(
        authors: {franzapPubkey},
        since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
      );
      final filter2 = RequestFilter(
        authors: {franzapPubkey},
        until: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
      );
      final expected = [
        RequestFilter(
          authors: {franzapPubkey},
        )
      ];
      expect(RequestFilter.merge(filter1, filter2), expected);
    });

    // Test non-mergeable filters
    test("filters with different authors and kinds - not mergeable", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
      );
      final filter2 = RequestFilter(
        authors: {franzapPubkey},
        kinds: {2},
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
          kinds: {1},
        ),
        RequestFilter(
          authors: {franzapPubkey},
          kinds: {2},
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("filters with different non-array properties - not mergeable", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        search: 'hello',
      );
      final filter2 = RequestFilter(
        authors: {nielPubkey},
        search: 'world',
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
          search: 'hello',
        ),
        RequestFilter(
          authors: {nielPubkey},
          search: 'world',
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test(
      "complex filters with multiple different properties - not mergeable",
      () {
        final filter1 = RequestFilter(
          authors: {nielPubkey},
          kinds: {1},
          limit: 10,
          since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
        );
        final filter2 = RequestFilter(
          authors: {nielPubkey},
          kinds: {1, 2},
          limit: 20,
          until: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
        );
        final expected = [
          RequestFilter(
            authors: {nielPubkey},
            kinds: {1},
            limit: 10,
            since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
          ),
          RequestFilter(
            authors: {nielPubkey},
            kinds: {1, 2},
            limit: 20,
            until: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
          ),
        ];
        final result = RequestFilter.merge(filter1, filter2);
        expect(result, equals(expected));
      },
    );

    test(
      "complex filters with different authors and scalars - not mergeable",
      () {
        final filter1 = RequestFilter(
          authors: {nielPubkey},
          kinds: {1},
          limit: 10,
          since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
        );
        final filter2 = RequestFilter(
          authors: {nielPubkey, franzapPubkey},
          kinds: {1},
          limit: 20,
          until: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
        );
        final expected = [
          RequestFilter(
            authors: {nielPubkey},
            kinds: {1},
            limit: 10,
            since: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
          ),
          RequestFilter(
            authors: {nielPubkey, franzapPubkey},
            kinds: {1},
            limit: 20,
            until: DateTime.fromMillisecondsSinceEpoch(200 * 1000),
          ),
        ];
        final result = RequestFilter.merge(filter1, filter2);
        expect(result, equals(expected));
      },
    );

    // Test deduplication in merged arrays
    test("deduplicates merged arrays", () {
      final filter1 = RequestFilter(
        tags: {
          '#e': {'tag1', 'tag2', 'tag3'}
        },
      );
      final filter2 = RequestFilter(
        tags: {
          '#e': {'tag2', 'tag3', 'tag4'}
        },
      );
      final expected = [
        RequestFilter(
          tags: {
            '#e': {'tag1', 'tag2', 'tag3', 'tag4'}
          },
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("authors and tags", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        tags: {
          '#e': {'y'}
        },
      );
      final filter2 = RequestFilter(
        authors: {nielPubkey},
        tags: {
          '#e': {'z'}
        },
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
          tags: {
            '#e': {'y', 'z'}
          },
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("authors and tags unmergeable", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        tags: {
          '#e': {'y'}
        },
      );
      final filter2 = RequestFilter(
        authors: {franzapPubkey},
        tags: {
          '#e': {'z'}
        },
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
          tags: {
            '#e': {'y'}
          },
        ),
        RequestFilter(
          authors: {franzapPubkey},
          tags: {
            '#e': {'z'}
          },
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("kinds and tags mergeable", () {
      final filter1 = RequestFilter(
        kinds: {1},
        tags: {
          '#e': {'z'}
        },
      );
      final filter2 = RequestFilter(
        kinds: {2},
        tags: {
          '#e': {'z'}
        },
      );
      final expected = [
        RequestFilter(
          kinds: {1, 2},
          tags: {
            '#e': {'z'}
          },
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("kinds and tags unmergeable", () {
      final filter1 = RequestFilter(
        kinds: {1},
        tags: {
          '#e': {'y'}
        },
      );
      final filter2 = RequestFilter(
        kinds: {2},
        tags: {
          '#e': {'z'}
        },
      );
      final expected = [
        RequestFilter(
          kinds: {1},
          tags: {
            '#e': {'y'}
          },
        ),
        RequestFilter(
          kinds: {2},
          tags: {
            '#e': {'z'}
          },
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("one filter missing a property (unbounded) - not mergeable", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
      );
      final filter2 = RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
        ),
        RequestFilter(
          authors: {nielPubkey},
          kinds: {1},
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    // New tests from examples
    test("merges different author arrays", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
      );
      final filter2 = RequestFilter(
        authors: {franzapPubkey},
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey, franzapPubkey},
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("merges different author arrays with same kinds", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
      );
      final filter2 = RequestFilter(
        authors: {franzapPubkey},
        kinds: {1},
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey, franzapPubkey},
          kinds: {1},
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("merges different author arrays with same since", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        since: DateTime.fromMillisecondsSinceEpoch(1 * 1000),
      );
      final filter2 = RequestFilter(
        authors: {franzapPubkey},
        since: DateTime.fromMillisecondsSinceEpoch(1 * 1000),
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey, franzapPubkey},
          since: DateTime.fromMillisecondsSinceEpoch(1 * 1000),
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("merges different author arrays with different since", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        since: DateTime.fromMillisecondsSinceEpoch(1 * 1000),
      );
      final filter2 = RequestFilter(
        authors: {franzapPubkey},
        since: DateTime.fromMillisecondsSinceEpoch(2 * 1000),
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
          since: DateTime.fromMillisecondsSinceEpoch(1 * 1000),
        ),
        RequestFilter(
          authors: {franzapPubkey},
          since: DateTime.fromMillisecondsSinceEpoch(2 * 1000),
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("doesn't merge different author arrays with same limit", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        limit: 10,
      );
      final filter2 = RequestFilter(
        authors: {franzapPubkey},
        limit: 10,
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
          limit: 10,
        ),
        RequestFilter(
          authors: {franzapPubkey},
          limit: 10,
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("merges different kinds arrays with same since", () {
      final filter1 = RequestFilter(
        kinds: {3},
        since: DateTime.fromMillisecondsSinceEpoch(1 * 1000),
      );
      final filter2 = RequestFilter(
        kinds: {4},
        since: DateTime.fromMillisecondsSinceEpoch(1 * 1000),
      );
      final expected = [
        RequestFilter(
          kinds: {3, 4},
          since: DateTime.fromMillisecondsSinceEpoch(1 * 1000),
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("doesn't merge different kinds arrays with same limit", () {
      final filter1 = RequestFilter(
        kinds: {1},
        limit: 10,
      );
      final filter2 = RequestFilter(
        kinds: {2},
        limit: 10,
      );
      final expected = [
        RequestFilter(
          kinds: {1},
          limit: 10,
        ),
        RequestFilter(
          kinds: {2},
          limit: 10,
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("doesn't merge different tags arrays with same limit", () {
      final filter1 = RequestFilter(
        tags: {
          '#e': {'a'}
        },
        limit: 10,
      );
      final filter2 = RequestFilter(
        tags: {
          '#e': {'b'}
        },
        limit: 10,
      );
      final expected = [
        RequestFilter(
          tags: {
            '#e': {'a'}
          },
          limit: 10,
        ),
        RequestFilter(
          tags: {
            '#e': {'b'}
          },
          limit: 10,
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("merges arrays when multiple properties match", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
        tags: {
          '#e': {'z'}
        },
      );
      final filter2 = RequestFilter(
        authors: {franzapPubkey},
        kinds: {1},
        tags: {
          '#e': {'z'}
        },
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey, franzapPubkey},
          kinds: {1},
          tags: {
            '#e': {'z'}
          },
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("merges kinds arrays when authors and tags match", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        kinds: {1, 2},
        tags: {
          '#e': {'z'}
        },
      );
      final filter2 = RequestFilter(
        authors: {nielPubkey},
        kinds: {3, 4},
        tags: {
          '#e': {'z'}
        },
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
          kinds: {1, 2, 3, 4},
          tags: {
            '#e': {'z'}
          },
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("doesn't merge when multiple array properties differ", () {
      final filter1 = RequestFilter(
        authors: {nielPubkey},
        kinds: {1},
        tags: {
          '#e': {'z'}
        },
      );
      final filter2 = RequestFilter(
        authors: {franzapPubkey},
        kinds: {2},
        tags: {
          '#e': {'z'}
        },
      );
      final expected = [
        RequestFilter(
          authors: {nielPubkey},
          kinds: {1},
          tags: {
            '#e': {'z'}
          },
        ),
        RequestFilter(
          authors: {franzapPubkey},
          kinds: {2},
          tags: {
            '#e': {'z'}
          },
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("merges simple ids arrays", () {
      final [
        id1,
        id2,
        id3
      ] = [generate64Hex(), generate64Hex(), generate64Hex()];
      final filter1 = RequestFilter(
        ids: {id1, id2},
      );
      final filter2 = RequestFilter(
        ids: {id3},
      );
      final expected = [
        RequestFilter(
          ids: {id1, id2, id3},
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("takes min since when merging", () {
      final filter1 = RequestFilter(
        kinds: {1},
        since: DateTime.fromMillisecondsSinceEpoch(1 * 1000),
      );
      final filter2 = RequestFilter(
        kinds: {1},
        since: DateTime.fromMillisecondsSinceEpoch(2 * 1000),
      );
      final expected = [
        RequestFilter(
          kinds: {1},
          since: DateTime.fromMillisecondsSinceEpoch(1 * 1000),
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });

    test("takes max until when merging", () {
      final filter1 = RequestFilter(
        kinds: {1},
        until: DateTime.fromMillisecondsSinceEpoch(1 * 1000),
      );
      final filter2 = RequestFilter(
        kinds: {1},
        until: DateTime.fromMillisecondsSinceEpoch(2 * 1000),
      );
      final expected = [
        RequestFilter(
          kinds: {1},
          until: DateTime.fromMillisecondsSinceEpoch(2 * 1000),
        ),
      ];
      final result = RequestFilter.merge(filter1, filter2);
      expect(result, equals(expected));
    });
  });

  group('Merge multiple', () {
    test("empty array returns empty array", () {
      final filters = <RequestFilter>[];
      final expected = <RequestFilter>[];
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
        final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
        final result = RequestFilter.mergeMultiple(filters);
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
        final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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

      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
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
      final result = RequestFilter.mergeMultiple(filters);
      expect(result, unorderedEquals(expected));
    });
  });
}

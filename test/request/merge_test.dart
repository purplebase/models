import 'package:models/models.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
    expect(result, equals(expected));
  });

  test("ids-only filters - limits less than length and ids are not merged", () {
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    expect(mergeRequests(filter1, filter2), expected);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
      final result = mergeRequests(filter1, filter2);
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
      final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
    expect(result, equals(expected));
  });

  test("merges simple ids arrays", () {
    final [id1, id2, id3] = [generate64Hex(), generate64Hex(), generate64Hex()];
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
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
    final result = mergeRequests(filter1, filter2);
    expect(result, equals(expected));
  });
}

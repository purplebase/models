import 'package:models/models.dart';
import 'package:test/test.dart';

import '../helpers/helpers.dart';

/// Test case for RequestFilter.merge (pair merge)
typedef MergePairCase = ({
  String name,
  RequestFilter f1,
  RequestFilter f2,
  List<RequestFilter> expected,
});

/// Test case for RequestFilter.mergeMultiple
typedef MergeMultipleCase = ({
  String name,
  List<RequestFilter> filters,
  List<RequestFilter> expected,
});

void main() {
  final hex = Utils.generateRandomHex64;

  group('RequestFilter.merge (pairs)', () {
    // Generate IDs once for consistent tests
    final id1 = hex();
    final id2 = hex();
    final id3 = hex();
    final id4 = hex();

    final pairCases = <MergePairCase>[
      // Limit handling
      (
        name: 'identical filters - bigger limit wins',
        f1: RequestFilter(authors: {Pubkeys.niel}, limit: 10),
        f2: RequestFilter(authors: {Pubkeys.niel}, limit: 20),
        expected: [RequestFilter(authors: {Pubkeys.niel}, limit: 20)],
      ),
      (
        name: 'identical filters - no limit wins over having limit',
        f1: RequestFilter(authors: {Pubkeys.niel}, limit: 10),
        f2: RequestFilter(authors: {Pubkeys.niel}),
        expected: [RequestFilter(authors: {Pubkeys.niel})],
      ),

      // IDs-only merging
      (
        name: 'ids-only - limits added, ids merged',
        f1: RequestFilter(ids: {id1, id2}, limit: 10),
        f2: RequestFilter(ids: {id3, id4}, limit: 20),
        expected: [RequestFilter(ids: {id1, id2, id3, id4})],
      ),
      (
        name: 'ids-only - limit less than length prevents merge',
        f1: RequestFilter(ids: {id1, id2}, limit: 1),
        f2: RequestFilter(ids: {id3, id4}),
        expected: [
          RequestFilter(ids: {id1, id2}, limit: 1),
          RequestFilter(ids: {id3, id4}),
        ],
      ),
      (
        name: 'ids-only - one without limit',
        f1: RequestFilter(ids: {id1, id2}, limit: 10),
        f2: RequestFilter(ids: {id3, id4}),
        expected: [RequestFilter(ids: {id1, id2, id3, id4})],
      ),
      (
        name: 'ids-only - both without limit',
        f1: RequestFilter(ids: {id1, id2}),
        f2: RequestFilter(ids: {id3, id4}),
        expected: [RequestFilter(ids: {id1, id2, id3, id4})],
      ),

      // Array merging
      (
        name: 'merges authors arrays',
        f1: RequestFilter(authors: {Pubkeys.niel, Pubkeys.franzap}),
        f2: RequestFilter(authors: {Pubkeys.franzap, Pubkeys.verbiricha}),
        expected: [
          RequestFilter(
              authors: {Pubkeys.niel, Pubkeys.franzap, Pubkeys.verbiricha})
        ],
      ),
      (
        name: 'merges kinds arrays',
        f1: RequestFilter(kinds: {1, 2}),
        f2: RequestFilter(kinds: {2, 3}),
        expected: [RequestFilter(kinds: {1, 2, 3})],
      ),
      (
        name: 'merges different author arrays',
        f1: RequestFilter(authors: {Pubkeys.niel}),
        f2: RequestFilter(authors: {Pubkeys.franzap}),
        expected: [RequestFilter(authors: {Pubkeys.niel, Pubkeys.franzap})],
      ),
      (
        name: 'merges authors with same kinds',
        f1: RequestFilter(authors: {Pubkeys.niel}, kinds: {1}),
        f2: RequestFilter(authors: {Pubkeys.franzap}, kinds: {1}),
        expected: [
          RequestFilter(authors: {Pubkeys.niel, Pubkeys.franzap}, kinds: {1})
        ],
      ),

      // Since/until handling
      (
        name: 'takes min since and max until when merging',
        f1: RequestFilter(
          authors: {Pubkeys.niel},
          since: DateTime.fromMillisecondsSinceEpoch(100000),
          until: DateTime.fromMillisecondsSinceEpoch(200000),
        ),
        f2: RequestFilter(
          authors: {Pubkeys.niel},
          since: DateTime.fromMillisecondsSinceEpoch(50000),
          until: DateTime.fromMillisecondsSinceEpoch(300000),
        ),
        expected: [
          RequestFilter(
            authors: {Pubkeys.niel},
            since: DateTime.fromMillisecondsSinceEpoch(50000),
            until: DateTime.fromMillisecondsSinceEpoch(300000),
          )
        ],
      ),
      (
        name: 'handles since and until - removes both when complementary',
        f1: RequestFilter(
          authors: {Pubkeys.franzap},
          since: DateTime.fromMillisecondsSinceEpoch(100000),
        ),
        f2: RequestFilter(
          authors: {Pubkeys.franzap},
          until: DateTime.fromMillisecondsSinceEpoch(200000),
        ),
        expected: [RequestFilter(authors: {Pubkeys.franzap})],
      ),
      (
        name: 'takes min since when merging',
        f1: RequestFilter(
          kinds: {1},
          since: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
        f2: RequestFilter(
          kinds: {1},
          since: DateTime.fromMillisecondsSinceEpoch(2000),
        ),
        expected: [
          RequestFilter(
            kinds: {1},
            since: DateTime.fromMillisecondsSinceEpoch(1000),
          )
        ],
      ),
      (
        name: 'takes max until when merging',
        f1: RequestFilter(
          kinds: {1},
          until: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
        f2: RequestFilter(
          kinds: {1},
          until: DateTime.fromMillisecondsSinceEpoch(2000),
        ),
        expected: [
          RequestFilter(
            kinds: {1},
            until: DateTime.fromMillisecondsSinceEpoch(2000),
          )
        ],
      ),
      (
        name: 'different authors with same since merge',
        f1: RequestFilter(
          authors: {Pubkeys.niel},
          since: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
        f2: RequestFilter(
          authors: {Pubkeys.franzap},
          since: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
        expected: [
          RequestFilter(
            authors: {Pubkeys.niel, Pubkeys.franzap},
            since: DateTime.fromMillisecondsSinceEpoch(1000),
          )
        ],
      ),
      (
        name: 'different authors with different since do not merge',
        f1: RequestFilter(
          authors: {Pubkeys.niel},
          since: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
        f2: RequestFilter(
          authors: {Pubkeys.franzap},
          since: DateTime.fromMillisecondsSinceEpoch(2000),
        ),
        expected: [
          RequestFilter(
            authors: {Pubkeys.niel},
            since: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
          RequestFilter(
            authors: {Pubkeys.franzap},
            since: DateTime.fromMillisecondsSinceEpoch(2000),
          ),
        ],
      ),

      // Limit prevents merge with different arrays
      (
        name: 'different authors with same limit do not merge',
        f1: RequestFilter(authors: {Pubkeys.niel}, limit: 10),
        f2: RequestFilter(authors: {Pubkeys.franzap}, limit: 10),
        expected: [
          RequestFilter(authors: {Pubkeys.niel}, limit: 10),
          RequestFilter(authors: {Pubkeys.franzap}, limit: 10),
        ],
      ),
      (
        name: 'different kinds with same limit do not merge',
        f1: RequestFilter(kinds: {1}, limit: 10),
        f2: RequestFilter(kinds: {2}, limit: 10),
        expected: [
          RequestFilter(kinds: {1}, limit: 10),
          RequestFilter(kinds: {2}, limit: 10),
        ],
      ),
      (
        name: 'different tags with same limit do not merge',
        f1: RequestFilter(
            tags: {
              '#e': {'a'}
            },
            limit: 10),
        f2: RequestFilter(
            tags: {
              '#e': {'b'}
            },
            limit: 10),
        expected: [
          RequestFilter(
              tags: {
                '#e': {'a'}
              },
              limit: 10),
          RequestFilter(
              tags: {
                '#e': {'b'}
              },
              limit: 10),
        ],
      ),

      // Non-mergeable filters
      (
        name: 'different authors and kinds - not mergeable',
        f1: RequestFilter(authors: {Pubkeys.niel}, kinds: {1}),
        f2: RequestFilter(authors: {Pubkeys.franzap}, kinds: {2}),
        expected: [
          RequestFilter(authors: {Pubkeys.niel}, kinds: {1}),
          RequestFilter(authors: {Pubkeys.franzap}, kinds: {2}),
        ],
      ),
      (
        name: 'different search strings - not mergeable',
        f1: RequestFilter(authors: {Pubkeys.niel}, search: 'hello'),
        f2: RequestFilter(authors: {Pubkeys.niel}, search: 'world'),
        expected: [
          RequestFilter(authors: {Pubkeys.niel}, search: 'hello'),
          RequestFilter(authors: {Pubkeys.niel}, search: 'world'),
        ],
      ),
      (
        name: 'one filter missing property (unbounded) - not mergeable',
        f1: RequestFilter(authors: {Pubkeys.niel}),
        f2: RequestFilter(authors: {Pubkeys.niel}, kinds: {1}),
        expected: [
          RequestFilter(authors: {Pubkeys.niel}),
          RequestFilter(authors: {Pubkeys.niel}, kinds: {1}),
        ],
      ),

      // Tags merging
      (
        name: 'deduplicates merged tag arrays',
        f1: RequestFilter(tags: {
          '#e': {'tag1', 'tag2', 'tag3'}
        }),
        f2: RequestFilter(tags: {
          '#e': {'tag2', 'tag3', 'tag4'}
        }),
        expected: [
          RequestFilter(tags: {
            '#e': {'tag1', 'tag2', 'tag3', 'tag4'}
          })
        ],
      ),
      (
        name: 'authors and tags - same authors merge tags',
        f1: RequestFilter(
            authors: {Pubkeys.niel},
            tags: {
              '#e': {'y'}
            }),
        f2: RequestFilter(
            authors: {Pubkeys.niel},
            tags: {
              '#e': {'z'}
            }),
        expected: [
          RequestFilter(
              authors: {Pubkeys.niel},
              tags: {
                '#e': {'y', 'z'}
              })
        ],
      ),
      (
        name: 'authors and tags - different authors not mergeable',
        f1: RequestFilter(
            authors: {Pubkeys.niel},
            tags: {
              '#e': {'y'}
            }),
        f2: RequestFilter(
            authors: {Pubkeys.franzap},
            tags: {
              '#e': {'z'}
            }),
        expected: [
          RequestFilter(
              authors: {Pubkeys.niel},
              tags: {
                '#e': {'y'}
              }),
          RequestFilter(
              authors: {Pubkeys.franzap},
              tags: {
                '#e': {'z'}
              }),
        ],
      ),
      (
        name: 'kinds and tags - same tags merge kinds',
        f1: RequestFilter(
            kinds: {1},
            tags: {
              '#e': {'z'}
            }),
        f2: RequestFilter(
            kinds: {2},
            tags: {
              '#e': {'z'}
            }),
        expected: [
          RequestFilter(
              kinds: {1, 2},
              tags: {
                '#e': {'z'}
              })
        ],
      ),
      (
        name: 'kinds and tags - different tags not mergeable',
        f1: RequestFilter(
            kinds: {1},
            tags: {
              '#e': {'y'}
            }),
        f2: RequestFilter(
            kinds: {2},
            tags: {
              '#e': {'z'}
            }),
        expected: [
          RequestFilter(
              kinds: {1},
              tags: {
                '#e': {'y'}
              }),
          RequestFilter(
              kinds: {2},
              tags: {
                '#e': {'z'}
              }),
        ],
      ),

      // Complex multi-property cases
      (
        name: 'merges arrays when multiple properties match',
        f1: RequestFilter(
            authors: {Pubkeys.niel},
            kinds: {1},
            tags: {
              '#e': {'z'}
            }),
        f2: RequestFilter(
            authors: {Pubkeys.franzap},
            kinds: {1},
            tags: {
              '#e': {'z'}
            }),
        expected: [
          RequestFilter(
              authors: {Pubkeys.niel, Pubkeys.franzap},
              kinds: {1},
              tags: {
                '#e': {'z'}
              })
        ],
      ),
      (
        name: 'merges kinds when authors and tags match',
        f1: RequestFilter(
            authors: {Pubkeys.niel},
            kinds: {1, 2},
            tags: {
              '#e': {'z'}
            }),
        f2: RequestFilter(
            authors: {Pubkeys.niel},
            kinds: {3, 4},
            tags: {
              '#e': {'z'}
            }),
        expected: [
          RequestFilter(
              authors: {Pubkeys.niel},
              kinds: {1, 2, 3, 4},
              tags: {
                '#e': {'z'}
              })
        ],
      ),
      (
        name: 'does not merge when multiple array properties differ',
        f1: RequestFilter(
            authors: {Pubkeys.niel},
            kinds: {1},
            tags: {
              '#e': {'z'}
            }),
        f2: RequestFilter(
            authors: {Pubkeys.franzap},
            kinds: {2},
            tags: {
              '#e': {'z'}
            }),
        expected: [
          RequestFilter(
              authors: {Pubkeys.niel},
              kinds: {1},
              tags: {
                '#e': {'z'}
              }),
          RequestFilter(
              authors: {Pubkeys.franzap},
              kinds: {2},
              tags: {
                '#e': {'z'}
              }),
        ],
      ),
    ];

    for (final tc in pairCases) {
      test(tc.name, () {
        expect(RequestFilter.merge(tc.f1, tc.f2), equals(tc.expected));
      });
    }
  });

  group('RequestFilter.mergeMultiple', () {
    final id1 = hex();
    final id2 = hex();
    final id3 = hex();
    final id4 = hex();
    final id5 = hex();
    final id6 = hex();

    final multipleCases = <MergeMultipleCase>[
      // Base cases
      (
        name: 'empty array returns empty array',
        filters: <RequestFilter>[],
        expected: <RequestFilter>[],
      ),
      (
        name: 'single filter returns that filter',
        filters: [RequestFilter(authors: {Pubkeys.niel})],
        expected: [RequestFilter(authors: {Pubkeys.niel})],
      ),
      (
        name: 'two filters - same as regular merge',
        filters: [
          RequestFilter(authors: {Pubkeys.niel}),
          RequestFilter(authors: {Pubkeys.franzap}),
        ],
        expected: [RequestFilter(authors: {Pubkeys.niel, Pubkeys.franzap})],
      ),

      // IDs-only filters
      (
        name: 'ids-only filters merged into one',
        filters: [
          RequestFilter(ids: {id1, id2}, limit: 1),
          RequestFilter(ids: {id3, id4}, limit: 10),
          RequestFilter(ids: {id5, id6}),
        ],
        expected: [
          RequestFilter(ids: {id1, id2}, limit: 1),
          RequestFilter(ids: {id3, id4, id5, id6}),
        ],
      ),
      (
        name: 'ids-only merged separately from other filters',
        filters: [
          RequestFilter(ids: {id1, id2}, limit: 5),
          RequestFilter(authors: {Pubkeys.niel}),
          RequestFilter(ids: {id3, id4}),
          RequestFilter(authors: {Pubkeys.franzap}),
        ],
        expected: [
          RequestFilter(ids: {id1, id2, id3, id4}),
          RequestFilter(authors: {Pubkeys.niel, Pubkeys.franzap}),
        ],
      ),

      // Property signature grouping
      (
        name: 'filters with different properties stay separate',
        filters: [
          RequestFilter(authors: {Pubkeys.niel}),
          RequestFilter(kinds: {1}),
          RequestFilter(tags: {
            '#e': {'x'}
          }),
        ],
        expected: [
          RequestFilter(authors: {Pubkeys.niel}),
          RequestFilter(kinds: {1}),
          RequestFilter(tags: {
            '#e': {'x'}
          }),
        ],
      ),
      (
        name: 'filters with same properties grouped and merged',
        filters: [
          RequestFilter(authors: {Pubkeys.niel}),
          RequestFilter(authors: {Pubkeys.franzap}),
          RequestFilter(kinds: {1}),
          RequestFilter(kinds: {2}),
        ],
        expected: [
          RequestFilter(authors: {Pubkeys.niel, Pubkeys.franzap}),
          RequestFilter(kinds: {1, 2}),
        ],
      ),

      // Iterative merging
      (
        name: 'iterative merging - filters merge after others merge',
        filters: [
          RequestFilter(
              authors: {Pubkeys.niel},
              tags: {
                '#e': {'x'}
              }),
          RequestFilter(
              authors: {Pubkeys.franzap},
              tags: {
                '#e': {'x'}
              }),
          RequestFilter(
              authors: {Pubkeys.franzap},
              tags: {
                '#e': {'y'}
              }),
        ],
        expected: [
          RequestFilter(
              authors: {Pubkeys.niel, Pubkeys.franzap},
              tags: {
                '#e': {'x'}
              }),
          RequestFilter(
              authors: {Pubkeys.franzap},
              tags: {
                '#e': {'y'}
              }),
        ],
      ),
      (
        name: 'complex iterative merging',
        filters: [
          RequestFilter(authors: {Pubkeys.niel}, kinds: {1, 2}),
          RequestFilter(authors: {Pubkeys.franzap}, kinds: {1, 2}),
          RequestFilter(authors: {Pubkeys.verbiricha}, kinds: {1, 2}),
          RequestFilter(authors: {Pubkeys.niel, Pubkeys.franzap}, kinds: {3}),
          RequestFilter(
              authors: {Pubkeys.franzap, Pubkeys.verbiricha}, kinds: {4}),
        ],
        expected: [
          RequestFilter(
              authors: {Pubkeys.niel, Pubkeys.franzap, Pubkeys.verbiricha},
              kinds: {1, 2}),
          RequestFilter(
              authors: {Pubkeys.niel, Pubkeys.franzap}, kinds: {3}),
          RequestFilter(
              authors: {Pubkeys.franzap, Pubkeys.verbiricha}, kinds: {4}),
        ],
      ),

      // Limit handling
      (
        name: 'filters with limit that cannot merge remain separate',
        filters: [
          RequestFilter(authors: {Pubkeys.niel}, kinds: {1}, limit: 10),
          RequestFilter(authors: {Pubkeys.franzap}, kinds: {1}, limit: 20),
          RequestFilter(authors: {Pubkeys.verbiricha}, kinds: {2}, limit: 30),
        ],
        expected: [
          RequestFilter(authors: {Pubkeys.niel}, kinds: {1}, limit: 10),
          RequestFilter(authors: {Pubkeys.franzap}, kinds: {1}, limit: 20),
          RequestFilter(authors: {Pubkeys.verbiricha}, kinds: {2}, limit: 30),
        ],
      ),

      // Since/until handling
      (
        name: 'different since values do not merge',
        filters: [
          RequestFilter(
            authors: {Pubkeys.niel},
            since: DateTime.fromMillisecondsSinceEpoch(100000),
          ),
          RequestFilter(
            authors: {Pubkeys.franzap},
            since: DateTime.fromMillisecondsSinceEpoch(200000),
          ),
          RequestFilter(
            authors: {Pubkeys.verbiricha},
            since: DateTime.fromMillisecondsSinceEpoch(150000),
          ),
        ],
        expected: [
          RequestFilter(
            authors: {Pubkeys.niel},
            since: DateTime.fromMillisecondsSinceEpoch(100000),
          ),
          RequestFilter(
            authors: {Pubkeys.franzap},
            since: DateTime.fromMillisecondsSinceEpoch(200000),
          ),
          RequestFilter(
            authors: {Pubkeys.verbiricha},
            since: DateTime.fromMillisecondsSinceEpoch(150000),
          ),
        ],
      ),

      // Tags merging
      (
        name: 'merges tag filters with same kinds',
        filters: [
          RequestFilter(
              kinds: {1},
              tags: {
                '#e': {'x'}
              }),
          RequestFilter(
              kinds: {1},
              tags: {
                '#e': {'y'}
              }),
          RequestFilter(
              kinds: {1},
              tags: {
                '#e': {'z'}
              }),
        ],
        expected: [
          RequestFilter(
              kinds: {1},
              tags: {
                '#e': {'x', 'y', 'z'}
              }),
        ],
      ),

      // Multiple differing array properties
      (
        name: 'more than one differing array property prevents merge',
        filters: [
          RequestFilter(
              authors: {Pubkeys.niel},
              kinds: {1},
              tags: {
                '#e': {'x'}
              }),
          RequestFilter(
              authors: {Pubkeys.franzap},
              kinds: {2},
              tags: {
                '#e': {'x'}
              }),
        ],
        expected: [
          RequestFilter(
              authors: {Pubkeys.niel},
              kinds: {1},
              tags: {
                '#e': {'x'}
              }),
          RequestFilter(
              authors: {Pubkeys.franzap},
              kinds: {2},
              tags: {
                '#e': {'x'}
              }),
        ],
      ),

      // Order independence
      (
        name: 'order independent - case 1',
        filters: [
          RequestFilter(authors: {Pubkeys.niel}, kinds: {1}),
          RequestFilter(authors: {Pubkeys.franzap}, kinds: {1}),
          RequestFilter(authors: {Pubkeys.verbiricha}, kinds: {2}),
        ],
        expected: [
          RequestFilter(authors: {Pubkeys.niel, Pubkeys.franzap}, kinds: {1}),
          RequestFilter(authors: {Pubkeys.verbiricha}, kinds: {2}),
        ],
      ),
      (
        name: 'order independent - case 2 (reversed input)',
        filters: [
          RequestFilter(authors: {Pubkeys.verbiricha}, kinds: {2}),
          RequestFilter(authors: {Pubkeys.niel}, kinds: {1}),
          RequestFilter(authors: {Pubkeys.franzap}, kinds: {1}),
        ],
        expected: [
          RequestFilter(authors: {Pubkeys.niel, Pubkeys.franzap}, kinds: {1}),
          RequestFilter(authors: {Pubkeys.verbiricha}, kinds: {2}),
        ],
      ),
    ];

    for (final tc in multipleCases) {
      test(tc.name, () {
        expect(RequestFilter.mergeMultiple(tc.filters),
            unorderedEquals(tc.expected));
      });
    }

    // Large test case with dynamically generated IDs
    test('large test with many filters', () {
      final authors = List.generate(11, (_) => hex());
      final [a1, a2, a3, b1, b2, c1, _, _, lId1, lId2, lId3] = authors;
      final lId4 = hex();

      final filters = [
        RequestFilter(authors: {a1}, kinds: {1}),
        RequestFilter(authors: {a2}, kinds: {1}),
        RequestFilter(authors: {a3}, kinds: {1}),
        RequestFilter(authors: {a1}, kinds: {2}),
        RequestFilter(authors: {a2}, kinds: {2}),
        RequestFilter(ids: {lId1, lId2}),
        RequestFilter(ids: {lId3, lId4}),
        RequestFilter(tags: {
          '#e': {'t1'}
        }),
        RequestFilter(tags: {
          '#e': {'t2'}
        }),
        RequestFilter(tags: {
          '#e': {'t3'}
        }),
        RequestFilter(authors: {b1}, limit: 10),
        RequestFilter(authors: {b2}, limit: 20),
        RequestFilter(
          authors: {c1},
          since: DateTime.fromMillisecondsSinceEpoch(100000),
        ),
      ];

      final expected = [
        RequestFilter(authors: {a1, a2, a3}, kinds: {1}),
        RequestFilter(authors: {a1, a2}, kinds: {2}),
        RequestFilter(ids: {lId1, lId2, lId3, lId4}),
        RequestFilter(tags: {
          '#e': {'t1', 't2', 't3'}
        }),
        RequestFilter(authors: {b1}, limit: 10),
        RequestFilter(authors: {b2}, limit: 20),
        RequestFilter(
          authors: {c1},
          since: DateTime.fromMillisecondsSinceEpoch(100000),
        ),
      ];

      expect(RequestFilter.mergeMultiple(filters), unorderedEquals(expected));
    });
  });
}


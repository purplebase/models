import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  // Test limits with identical filters
  test("identical filters except limit - bigger limit wins", () {
    final filter1 = {
      'authors': ['a'],
      'limit': 10,
    };
    final filter2 = {
      'authors': ['a'],
      'limit': 20,
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("identical filters - no limit wins over having limit", () {
    final filter1 = {
      'authors': ['a'],
      'limit': 10,
    };
    final filter2 = {
      'authors': ['a'],
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  // Test ids-only filters
  test("ids-only filters - limits are added and ids are merged", () {
    final filter1 = {
      'ids': [1, 2],
      'limit': 10,
    };
    final filter2 = {
      'ids': [3, 4],
      'limit': 20,
    };

    final expected = false;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("ids-only filters - one without limit", () {
    final filter1 = {
      'ids': [1, 2],
      'limit': 10,
    };
    final filter2 = {
      'ids': [3, 4],
    };
    final expected = false;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("ids-only filters - both without limit", () {
    final filter1 = {
      'ids': [1, 2],
    };
    final filter2 = {
      'ids': [3, 4],
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  // Test array merging
  test("merges authors arrays", () {
    final filter1 = {
      'authors': ['a', 'b'],
    };
    final filter2 = {
      'authors': ['b', 'c'],
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("merges kinds arrays", () {
    final filter1 = {
      'kinds': [1, 2],
    };
    final filter2 = {
      'kinds': [2, 3],
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  // Test since/until handling
  test("handles since (min) and until (max)", () {
    final filter1 = {
      'authors': ['a'],
      'since': 100,
      'until': 200,
    };
    final filter2 = {
      'authors': ['a'],
      'since': 50,
      'until': 300,
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test('handles since and until', () {
    final filter1 = {
      'authors': ['a'],
      'since': 100,
    };
    final filter2 = {
      'authors': ['b'],
      'until': 200,
    };
    final expected = false;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  // Test non-mergeable filters
  test("filters with different authors and kinds - not mergeable", () {
    final filter1 = {
      'authors': ['a'],
      'kinds': [1],
    };
    final filter2 = {
      'authors': ['b'],
      'kinds': [2],
    };
    final expected = false;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("filters with different non-array properties - not mergeable", () {
    final filter1 = {
      'authors': ['a'],
      'search': 'hello',
    };
    final filter2 = {
      'authors': ['a'],
      'search': 'world',
    };
    final expected = false;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test(
    "complex filters with multiple different properties - not mergeable",
    () {
      final filter1 = {
        'authors': ['a'],
        'kinds': [1],
        'limit': 10,
        'since': 100,
      };
      final filter2 = {
        'authors': ['a'],
        'kinds': [1, 2],
        'limit': 20,
        'until': 200,
      };
      final expected = false;
      final result = canMerge(filter1, filter2);
      expect(result, equals(expected));
    },
  );

  test(
    "complex filters with different authors and scalars - not mergeable",
    () {
      final filter1 = {
        'authors': ['a'],
        'kinds': [1],
        'limit': 10,
        'since': 100,
      };
      final filter2 = {
        'authors': ['a', 'b'],
        'kinds': [1],
        'limit': 20,
        'until': 200,
      };
      final expected = false;
      final result = canMerge(filter1, filter2);
      expect(result, equals(expected));
    },
  );

  // Test deduplication in merged arrays
  test("deduplicates merged arrays", () {
    final filter1 = {
      '#e': ['tag1', 'tag2', 'tag3'],
    };
    final filter2 = {
      '#e': ['tag2', 'tag3', 'tag4'],
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("authors and tags", () {
    final filter1 = {
      'authors': ['a'],
      '#e': ['y'],
    };
    final filter2 = {
      'authors': ['a'],
      '#e': ['z'],
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("authors and tags unmergeable", () {
    final filter1 = {
      'authors': ['a'],
      '#e': ['y'],
    };
    final filter2 = {
      'authors': ['b'],
      '#e': ['z'],
    };
    final expected = false;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("kinds and tags mergeable", () {
    final filter1 = {
      'kinds': [1],
      '#e': ['z'],
    };
    final filter2 = {
      'kinds': [2],
      '#e': ['z'],
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("kinds and tags unmergeable", () {
    final filter1 = {
      'kinds': [1],
      '#e': ['y'],
    };
    final filter2 = {
      'kinds': [2],
      '#e': ['z'],
    };
    final expected = false;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("one filter missing a property (unbounded) - not mergeable", () {
    final filter1 = {
      'authors': ['a'],
    };
    final filter2 = {
      'authors': ['a'],
      'kinds': [1],
    };
    final expected = false;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  // New tests from examples
  test("merges different author arrays", () {
    final filter1 = {
      'authors': ['a'],
    };
    final filter2 = {
      'authors': ['b'],
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("merges different author arrays with same kinds", () {
    final filter1 = {
      'authors': ['a'],
      'kinds': [1],
    };
    final filter2 = {
      'authors': ['b'],
      'kinds': [1],
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("merges different author arrays with same since", () {
    final filter1 = {
      'authors': ['a'],
      'since': 1,
    };
    final filter2 = {
      'authors': ['b'],
      'since': 1,
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("merges different author arrays with different since", () {
    final filter1 = {
      'authors': ['a'],
      'since': 1,
    };
    final filter2 = {
      'authors': ['b'],
      'since': 2,
    };
    final expected = false;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("doesn't merge different author arrays with same limit", () {
    final filter1 = {
      'authors': ['a'],
      'limit': 10,
    };
    final filter2 = {
      'authors': ['b'],
      'limit': 10,
    };
    final expected = false;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("merges different kinds arrays with same since", () {
    final filter1 = {
      'kinds': [3],
      'since': 1,
    };
    final filter2 = {
      'kinds': [4],
      'since': 1,
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("doesn't merge different kinds arrays with same limit", () {
    final filter1 = {
      'kinds': [1],
      'limit': 10,
    };
    final filter2 = {
      'kinds': [2],
      'limit': 10,
    };
    final expected = false;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("doesn't merge different tags arrays with same limit", () {
    final filter1 = {
      '#e': ['a'],
      'limit': 10,
    };
    final filter2 = {
      '#e': ['b'],
      'limit': 10,
    };
    final expected = false;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("merges arrays when multiple properties match", () {
    final filter1 = {
      'authors': ['a'],
      'kinds': [1],
      '#e': ['z'],
    };
    final filter2 = {
      'authors': ['b'],
      'kinds': [1],
      '#e': ['z'],
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("merges kinds arrays when authors and tags match", () {
    final filter1 = {
      'authors': ['a'],
      'kinds': [1, 2],
      '#e': ['z'],
    };
    final filter2 = {
      'authors': ['a'],
      'kinds': [3, 4],
      '#e': ['z'],
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("doesn't merge when multiple array properties differ", () {
    final filter1 = {
      'authors': ['a'],
      'kinds': [1],
      '#e': ['z'],
    };
    final filter2 = {
      'authors': ['b'],
      'kinds': [2],
      '#e': ['z'],
    };
    final expected = false;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("merges simple ids arrays", () {
    final filter1 = {
      'ids': [1, 2],
    };
    final filter2 = {
      'ids': [3],
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("takes min since when merging", () {
    final filter1 = {
      'kinds': [1],
      'since': 1,
    };
    final filter2 = {
      'kinds': [1],
      'since': 2,
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });

  test("takes max until when merging", () {
    final filter1 = {
      'kinds': [1],
      'until': 1,
    };
    final filter2 = {
      'kinds': [1],
      'until': 2,
    };
    final expected = true;
    final result = canMerge(filter1, filter2);
    expect(result, equals(expected));
  });
}

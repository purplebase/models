# Testing Guidelines

## Test Structure

```
test/
├── helpers/                 # Shared utilities
│   ├── helpers.dart         # Barrel export
│   ├── test_container.dart  # ProviderContainer extension
│   ├── fixtures.dart        # Pubkeys, sample events
│   └── test_data_generators.dart
├── helpers.dart             # Root re-export for backwards compat
├── core/                    # Signer, verifier, encryptable, relationships, events
├── models/                  # Per-model tests (one file per model)
├── nip44/                   # NIP-44 crypto & encoding
├── nwc/                     # Nostr Wallet Connect tests
├── request/                 # RequestFilter merge logic
├── storage/                 # Storage, queries, subscriptions
└── utils/                   # Async utilities
```

## Setup Pattern

Use the `ProviderContainer` extension for cleaner setup:

```dart
import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers/helpers.dart';

void main() {
  late ProviderContainer container;

  setUp(() async => container = await createTestContainer());
  tearDown(() => container.tearDown());

  group('ModelName', () {
    // tests here
  });
}
```

The extension provides:
- `container.storage` - Direct `DummyStorageNotifier` access
- `container.ref` - Get ref for model construction  
- `container.tearDown()` - Clean storage and dispose

## What to Test

### ✅ DO Test

**Complex parsing logic:**
```dart
test('parses dimensions into width/height', () {
  final video = PartialVideo(videoUrl: 'x', dimensions: '1920x1080').dummySign();
  expect(video.width, 1920);
  expect(video.height, 1080);
});
```

**Edge cases:**
```dart
test('handles malformed dimensions', () {
  expect(PartialVideo(videoUrl: 'x', dimensions: 'invalid').dummySign().width, isNull);
});
```

**Relationships:**
```dart
test('resolves author relationship', () async {
  final profile = PartialProfile(name: 'Test').dummySign(Pubkeys.niel);
  final note = PartialNote('hello').dummySign(Pubkeys.niel);
  await container.storage.save({profile, note});
  expect(note.author.value, profile);
});
```

**Business logic:**
```dart
test('isPortrait detection', () {
  final portrait = PartialShortFormPortraitVideo.withDimensions(
    videoUrl: 'x', width: 720, height: 1280,
  ).dummySign();
  expect(portrait.isPortrait, isTrue);
});
```

**Serialization roundtrips (once per model):**
```dart
test('serialization roundtrip', () {
  final video = PartialVideo(videoUrl: 'x', title: 'Test').dummySign();
  final restored = Video.fromMap(video.toMap(), container.ref);
  expect(restored.toMap(), video.toMap());
});
```

### ❌ DON'T Test

**Simple getter/setter roundtrips:**
```dart
// BAD - This tests Dart, not your code
test('title getter returns set value', () {
  final video = PartialVideo(title: 'My Title', videoUrl: 'x').dummySign();
  expect(video.title, 'My Title');  
});
```

**Every property individually:**
```dart
// BAD - Verbose and low value
expect(video.title, 'Sunset Timelapse');
expect(video.altText, 'Time-lapse video...');
expect(video.location, 'Mount Fuji, Japan');
expect(video.mimeType, 'video/mp4');
// ... 20 more lines
```

## Table-Driven Tests

For functions with many input/output combinations, use table-driven tests:

```dart
typedef MergeCase = ({
  String name,
  RequestFilter f1,
  RequestFilter f2,
  List<RequestFilter> expected,
});

final cases = <MergeCase>[
  (
    name: 'merges authors arrays',
    f1: RequestFilter(authors: {Pubkeys.niel}),
    f2: RequestFilter(authors: {Pubkeys.franzap}),
    expected: [RequestFilter(authors: {Pubkeys.niel, Pubkeys.franzap})],
  ),
  // more cases...
];

for (final tc in cases) {
  test(tc.name, () {
    expect(RequestFilter.merge(tc.f1, tc.f2), equals(tc.expected));
  });
}
```

## Fixtures

Use `Pubkeys` class for consistent test pubkeys:

```dart
import '../helpers/helpers.dart';

final note = PartialNote('test').dummySign(Pubkeys.niel);
final profile = PartialProfile(name: 'Test').dummySign(Pubkeys.franzap);
```

Use `SampleEvents` for JSON event fixtures:

```dart
final profile = Profile.fromMap(
  jsonDecode(SampleEvents.franzapProfile),
  container.ref,
);
```


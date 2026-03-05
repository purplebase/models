---
description: Model authoring — partial generation, API documentation, testing standards
alwaysApply: true
---

# models — Model Authoring

**Follow this guideline whenever a model is created or modified.**

## Core Philosophy

Models speak human language. They bridge NIP technicisms and real-world concepts:

- **Human terms**: `displayName` not `name_tag`, `author` not `pubkey`
- **Abstract NIP details**: hide tag complexity behind intuitive properties
- **Natural relationships**: `article.comments` not `article.getRelatedEvents(kind: 1)`
- **Domain focus**: think like a domain expert, not a protocol engineer

## Defining a Model

```dart
// Immutable model (wraps a signed event)
class Note extends RegularModel<Note> {
  Note.fromMap(super.map, super.ref) : super.fromMap();

  String get content => event.content;
  String? get subject => event.getFirstTagValue('subject');
}

// Mutable partial (for creation/editing)
class PartialNote extends RegularPartialModel<Note> {
  String get content => event.content;
  set content(String value) => event.content = value;

  String? get subject => event.getFirstTagValue('subject');
  set subject(String? value) => event.setTagValue('subject', value);
}
```

Choose the base class from the kind range:

| Kind range | Model base | Partial base |
|---|---|---|
| 1–9999 | `RegularModel` | `RegularPartialModel` |
| 10000–19999 | `ReplaceableModel` | `ReplaceablePartialModel` |
| 20000–29999 | `EphemeralModel` | `EphemeralPartialModel` |
| 30000–39999 | `ParameterizableReplaceableModel` | `ParameterizableReplaceablePartialModel` |

## Partial Model Methods

### What to generate

**Generate setters for:**
- Getters that read `event.getFirstTagValue('tag')`
- Getters that read `event.getTagSetValues('tag')`
- Getters that read `event.content`

**Skip (already inherited or not applicable):**
- Relationship properties (`BelongsTo`, `HasMany`)
- Base model properties: `id`, `createdAt`, `kind`, `pubkey`, `signature`
- Complex computed properties with business logic

### Patterns by property type

**Single tag value:**
```dart
String? get title => event.getFirstTagValue('title');
set title(String? value) => event.setTagValue('title', value);
```

**Tag set (multi-value):**
```dart
Set<String> get hashtags => event.getTagSetValues('t');
set hashtags(Set<String> value) => event.setTagValues('t', value);
void addHashtag(String? value) => event.addTagValue('t', value);
void removeHashtag(String? value) => event.removeTagWithValue('t', value);
```

**Content:**
```dart
String get text => event.content;
set text(String value) => event.content = value;
```

**Type conversions:**
- `int`: `int.tryParse(event.getFirstTagValue('x') ?? '')` / `value?.toString()`
- `DateTime`: `.toInt()?.toDate()` / `value?.toSeconds().toString()`

## Relationships

Name relationships as close to the class noun as possible:

```dart
// ✅
BelongsTo<Community> community;
HasMany<Note> notes;

// ❌
BelongsTo<Community> communityRelation;
HasMany<Note> posts;
```

Never create a `BelongsTo` that can never have a value — think "does X logically belong to Y?" before adding it. For reference tags (`'e'`, `'a'`, `'E'`, `'A'`), use `Request.fromIds()` — it handles both regular and replaceable event IDs.

## Registration

New models in the core library are registered in `lib/src/storage/storage.dart`:

```dart
Model.register(
  kind: 1234,
  constructor: ModelName.fromMap,
  partialConstructor: PartialModelName.fromMap,
);
```

After registering, update the **Registered Event Kinds** table in the root `README.md`.

One file per kind in `src/models/<name>.dart`. No `part`/`part of`.

## API Documentation Standards

All public members require documentation in human-readable language — no NIP jargon without explanation.

**Class:** business purpose and context
```dart
/// A user profile containing display information and social metadata.
```

**Getters:** what it means to humans
```dart
/// The user's chosen display name
/// Payment amount in satoshis
/// Set of topic tags for content discovery
```

**Setters/add/remove:** natural language actions
```dart
/// Sets the user's display name
/// Adds a topic tag for better content discovery
```

**Parameters:** business context, with units where relevant
```dart
/// [displayName] How the user wants to be shown to others
/// [relayUrl] WebSocket URL of the relay server
```

## Testing

Every new or modified model must have tests in `test/models/<name>_test.dart`.

Required coverage:
- Serialization roundtrip: `fromMap()` → `toMap()` → `fromMap()` produces identical result
- All getters return expected values from a known event map
- All partial setters and add/remove methods
- Null values, empty content, missing tags
- Any computed properties or validation rules

Test setup pattern:

```dart
void main() {
  late ProviderContainer container;
  late Ref ref;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = ProviderContainer();
    await container.read(initializationProvider(StorageConfiguration()).future);
    ref = container.read(refProvider);
    storage = container.read(storageNotifierProvider.notifier) as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.cancel();
    await storage.clear();
    container.dispose();
  });
}
```

Use `partial.dummySign(pubkey)` for tests that need signed models. Never use `DummySigner` in production paths.

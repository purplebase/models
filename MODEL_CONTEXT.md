# Creating and Registering New Models

**THIS DOCUMENT MUST BE FOLLOWED ANYTIME A MODEL IS CREATED OR MODIFIED**

This guide covers partial model generation and API documentation standards for Nostr event model classes.

## Audience: Library Authors vs Library Users

**Library Authors** (adding models to this library):
- Follow all sections below for core library models
- Register in `lib/src/storage/storage.dart`
- Update root `README.md` with registered kinds

**Library Users** (extending with custom models):
- Follow Part I and II patterns for your custom models
- Register using custom initialization providers in your app
- **⚠️ Research existing models first** - use `search_recipes` MCP tool and check NIPs
- **Custom kinds sacrifice interoperability** - use as last resort only

## Core Philosophy: Domain-Centric Models

These models are designed to **speak human language** and bridge the gap between NIP technicisms and real-world concepts. When working with models:

- **Use human terms**: `displayName` not `name_tag`, `author` not `pubkey`, `content` not `note_content`
- **Abstract NIP details**: Hide tag complexity behind intuitive properties
- **Domain focus**: Think like domain experts, not protocol engineers (this is the translation layer)
- **Natural relationships**: `article.comments` not `article.getRelatedEvents(kind: 1)`

---

## Part I: Partial Model Methods Generation

### Purpose
Generate mutable setters for immutable Nostr event model properties by adding methods directly to `PartialXXX` classes, making draft/editing states feel natural.

### Model Type Detection
Map the inheritance hierarchy to the correct base partial model class:
- `RegularModel` → `RegularPartialModel`
- `EphemeralModel` → `EphemeralPartialModel` 
- `ReplaceableModel` → `ReplaceablePartialModel`
- `ParameterizableReplaceableModel` → `ParameterizableReplaceablePartialModel`

### Property Analysis Rules

**✅ Generate methods for:**
- Getters that use `event.getFirstTagValue('tagName')`
- Getters that use `event.getTagSetValues('tagName')`
- Getters that only use `event.content`

**❌ Skip these (already inherited):**
- Relationship properties: `HasMany<Reaction> reactions`, `HasOne<Profile> author`
- Base model properties: `id`, `createdAt`, `kind`, `pubkey`, `signature`
- Complex computed properties with business logic
- Properties that don't directly map to event data

**💡 Relationship Tip:** For reference tags like `'e'`, `'a'`, `'E'`, `'A'` that point to other events, use `Request.fromIds()` - it handles both regular and replaceable event IDs automatically.

**⚠️ NEVER Do This:** Never create relationships that can't have values:
```dart
// ❌ BAD - This relationship will never have a value
BelongsTo<Calendar>(
  ref,
  null, // Calendars reference events, not the other way around
);
```
If the relationship direction doesn't make logical sense, don't create it. Think: "Does X logically belong to Y?" before adding `BelongsTo<Y>` relationships.

### Property Pattern Generation

#### Tag Value Properties
```dart
// Original getter:
String? get title => event.getFirstTagValue('title');

// Add to PartialXXX class:
String? get title => event.getFirstTagValue('title');
set title(String? value) => event.setTagValue('title', value);
```

#### Tag Set Properties  
```dart
// Original getter:
Set<String> get hashtags => event.getTagSetValues('t');

// Add to PartialXXX class:
Set<String> get hashtags => event.getTagSetValues('t');
set hashtags(Set<String> value) => event.setTagValues('t', value);
void addHashtag(String? value) => event.addTagValue('t', value);
void removeHashtag(String? value) => event.removeTagWithValue('t', value);
```

#### Content Properties
```dart
// Original getter:
String get text => event.content;

// Add to PartialXXX class:
String? get text => event.content.isEmpty ? null : event.content;
set text(String? value) => event.content = value ?? '';
```

### Type Handling
- **String**: Direct tag value access
- **int**: Use `int.tryParse()` and `value?.toString()`
- **DateTime**: Convert with `.toInt()?.toDate()` and `value?.toSeconds().toString()`
- **Set<String>**: Multi-value tags with add/remove methods

### Model Registration (CRITICAL)

#### For Library Authors
After creating a new model in the core library:

1. **Add registration** to `lib/src/storage/storage.dart`:
```dart
Model.register(
  kind: 1234, // Choose available Nostr kind number
  constructor: ModelName.fromMap,
  partialConstructor: PartialModelName.fromMap,
);
```

2. **Update the registered kinds table** in the root `README.md` file to keep the public documentation current and help other developers avoid kind conflicts.

#### For Library Users
Register custom models in your app initialization:

```dart
final customInitializationProvider = FutureProvider((ref) async {
  await ref.read(initializationProvider(StorageConfiguration()).future);
  
  Model.register(
    kind: 30402, // Research NIPs first!
    constructor: CustomModel.fromMap,
    partialConstructor: PartialCustomModel.fromMap,
  );
});
```

---

## Part II: API Documentation Standards

### Requirements
- **100% documentation** of all public members
- **Human-readable language** - explain in business terms, not NIP technicisms
- **No** `**Properties:**` or `**Methods:**` sections in class docs
- **Consistent patterns** for all member types

### Documentation Patterns

**Class:** Business purpose and human context
```dart
/// A user profile containing display information and social metadata.
/// 
/// Profiles represent how users present themselves to the network, including
/// their display name, bio, avatar, and contact information.
```

**Getters:** What it means to humans
```dart
/// The user's chosen display name
/// The article's publication timestamp  
/// Payment amount in satoshis
/// Set of topic tags for content discovery
```

**Setters:** Natural language actions
```dart
/// Sets the user's display name
/// Updates the publication timestamp
```

**Add/Remove methods:** Human-centered actions
```dart
/// Adds a topic tag for better content discovery
/// Removes a relay from the user's relay list
```

**Parameters:** Business context
```dart
/// [displayName] - How the user wants to be shown to others
/// [relayUrl] - WebSocket URL of the relay server
```

### Quality Checklist
- [ ] All getters/setters documented in human terms
- [ ] Units specified (satoshis, bytes, etc.)
- [ ] Model registration added
- [ ] No NIP jargon without explanation
- [ ] Relationships excluded from generation
- [ ] Business domain language used

---

## Part III: Comprehensive Testing Requirements

### Testing Philosophy
**Every new or modified model MUST have comprehensive tests.** Tests ensure reliability, catch regressions, and document expected behavior in human-readable scenarios.

### Required Test Coverage
- **Serialization/Deserialization** - `fromMap()` and `toMap()` roundtrips
- **Property Access** - All getters return expected values
- **Partial Model Methods** - All generated setters and utility methods
- **Edge Cases** - Null values, empty content, malformed data
- **Business Logic** - Any computed properties or validation rules

### Example Test Structure
Based on the excellent `test/models/community_test.dart`:

```dart
import 'dart:convert';
import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    ref = container.read(refProvider);
    storage = container.read(storageNotifierProvider.notifier) as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.cancel();
    await storage.clear();
    container.dispose();
  });

  group('Community', () {
    test('community creation and serialization', () async {
      // Create related models first
      final authorProfile = PartialProfile(name: 'Community Creator').dummySign(nielPubkey);
      await storage.save({authorProfile});

      final community = PartialCommunity(
        name: 'Test Community',
        createdAt: DateTime.parse('2025-04-10'),
        description: 'A community for testing',
        relayUrls: {'wss://test.relay'},
        contentSections: {
          CommunityContentSection(content: 'Chat', kinds: {9}),
          CommunityContentSection(content: 'Posts', kinds: {1}, feeInSats: 10),
        },
      ).dummySign(nielPubkey);

      await storage.save({community});
      
      // Test properties and relationships
      expect(community.name, 'Test Community');
      expect(community.author.value!.pubkey, nielPubkey);
      expect(community.relayUrls, contains('wss://test.relay'));
      expect(community.contentSections, hasLength(2));

      // Test serialization roundtrip
      final community2 = Community.fromMap(community.toMap(), ref);
      expect(community.toMap(), community2.toMap());
    });

    test('community relationships', () async {
      final community = PartialCommunity(
        name: 'Relationship Test',
        relayUrls: {'wss://test.relay'},
      ).dummySign(nielPubkey);

      // Create related content
      final chatMessage = PartialChatMessage(
        'Hello community!',
        community: community,
      ).dummySign();

      await storage.save({community, chatMessage});

      // Test relationships work properly
      final messages = community.chatMessages.toList();
      expect(messages, hasLength(1));
      expect(messages.first.content, 'Hello community!');
    });
  });
}
```

### Test Location
Create tests in `test/models/model_name_test.dart` following the existing project structure and naming conventions.

---

## Generation Steps
1. Identify model class getters that access `event` data (skip inherited relationships)
2. Determine correct base partial model class from inheritance
3. Generate setter methods directly in `PartialXXX` class (no mixins)
4. Add model registration to storage.dart
5. Document all public members in human-readable language
6. Use domain terminology over protocol specifics
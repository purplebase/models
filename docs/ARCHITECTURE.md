# Architecture

Technical overview of the internal design and extension points.

## Design Principles

1. **Domain-First**: Typed objects instead of raw JSON events
2. **Local-First**: Data stored locally, synchronized with relays in background
3. **Reactive**: Built on Riverpod StateNotifier
4. **Type-Safe**: Compile-time guarantees via Dart's type system
5. **Extensible**: Custom event kinds, storage backends, and signers

## Event System

The library uses a two-phase event system separating creation from storage.

**PartialEvent**: Mutable, unsigned events for creation. Contains `kind`, `content`, `tags`, and `createdAt`.

**ImmutableEvent**: Signed, immutable events from storage or relays. Adds `id`, `pubkey`, `signature`, and a `metadata` map for caching computed values.

**EventBase**: Mixin providing tag manipulation utilities (`getFirstTagValue`, `getTags`, `hasTagValue`, `addressableId`) shared by both types.

## Model Hierarchy

Models are sealed classes with four concrete subtypes matching Nostr event categories:

```
Model<E> (sealed)
├── RegularModel<E>           // Kind 1-9999 (non-replaceable)
├── ReplaceableModel<E>       // Kind 0, 3, 10000-19999
├── ParameterizableReplaceableModel<E>  // Kind 30000-39999
└── EphemeralModel<E>         // Kind 20000-29999
```

Each model validates its kind matches the expected category at construction time.

### Addressable IDs

Replaceable and parameterizable models use composite identifiers as primary keys:

- **Replaceable**: `kind:pubkey` (e.g., `0:abc123...`)
- **Parameterizable**: `kind:pubkey:d-tag` (e.g., `30023:abc123...:my-article`)

## Relationship System

Relationships are lazy-loaded query wrappers.

**BelongsTo<E>**: Single related model (nullable). Caches result after first access.

**HasMany<E>**: Collection implementing `Iterable<E>`. Caches list after first access.

Both provide synchronous (`value`, `toList()`) and asynchronous (`valueAsync`, `toListAsync()`) accessors.

### Relationship Discovery

The `and` parameter in queries returns a `Set<Relationship>` which the system uses to:

1. Extract `Request` objects from each relationship
2. Execute those requests with the configured `andSource`
3. Re-evaluate the function when primary models arrive (enabling nested relationships)

## Query Execution Pipeline

```
RequestFilter<E> → Request<E> → Storage.query()
                                      ↓
                            ┌─────────┴─────────┐
                            ↓                   ↓
                      LocalSource          RemoteSource
                            ↓                   ↓
                      querySync()          relay.subscribe()
                            ↓                   ↓
                            └─────────┬─────────┘
                                      ↓
                              schemaFilter (discard)
                                      ↓
                              model construction
                                      ↓
                              where filtering
                                      ↓
                              List<E> (final)
```

The `where` filter executes client-side after model construction, enabling filtering on computed properties and relationship data.

## Schema Filtering

`RequestFilter.schemaFilter` allows discarding events before model construction, applied to both local and remote data:

```dart
// Filter events by content length
query<Note>(
  authors: {pubkey},
  schemaFilter: (event) {
    final content = event['content'] as String?;
    return content != null && content.length > 10;
  },
);

// Filter by kind
query<Note>(
  authors: {pubkey},
  schemaFilter: (event) => event['kind'] == 1,
);

// Complex filtering (spam prevention)
query<Note>(
  authors: {pubkey},
  schemaFilter: (event) =>
    event['kind'] == 1 &&
    !(event['content'] as String?)?.contains('spam') == true,
);
```

**Key characteristics:**

- **Early rejection**: Events filtered before model construction
- **Raw event access**: Filter receives `Map<String, dynamic>` (not typed models)
- **Null means pass-through**: No filter set = all events accepted
- **Applies to all sources**: Works with LocalSource, RemoteSource, and LocalAndRemoteSource
- **Per-query**: Each query can have its own filter logic

**Use cases:**

- Content moderation (keyword filtering, length requirements)
- Kind-specific filtering beyond what relay filters support
- Author filtering beyond what relay filters support
- Deferred validation (check fields not in Nostr filter spec)

## Storage Interface

The `StorageNotifier` abstract class defines:

- `querySync<E>()` - Synchronous local query
- `query<E>()` - Async query with source control
- `save()` - Persist models locally
- `publish()` - Send to relays
- `clear()` / `obliterate()` - Remove data

### Model Registration

Models are registered during storage initialization, mapping event kinds to constructor functions:

```dart
Model.register(
  kind: 1,
  constructor: Note.fromMap,
  partialConstructor: PartialNote.fromMap,
);
```

## Signing Process

### Encryptable Hook

Models implementing `Encryptable` have content encrypted during signing via `prepareForSigning(signer)`. The flow:

1. `partialModel.signWith(signer)` called
2. If `Encryptable`, encryption occurs (e.g., NIP-44)
3. Event signed with BIP-340
4. `ImmutableEvent` created and wrapped in `Model`

### Signer State Management

Signers use internal Riverpod state notifiers. Public providers (`signedInPubkeysProvider`, `activeSignerProvider`) derive from this internal state.

## Extension Points

### Custom Event Kinds

```dart
class CustomEvent extends RegularModel<CustomEvent> {
  CustomEvent.fromMap(super.map, super.ref) : super.fromMap();
  String get customField => event.getFirstTagValue('custom') ?? '';
}

class PartialCustomEvent extends PartialModel<CustomEvent> {
  String customField = '';

  @override
  int get kind => 40000;

  @override
  List<List<String>> get tags => [['custom', customField]];
}

// Register during storage initialization
Model.register(kind: 40000, constructor: CustomEvent.fromMap);
```

### Custom Storage Backend

```dart
class CustomStorage extends StorageNotifier {
  @override
  Future<void> initialize(StorageConfiguration config) async {
    await super.initialize(config); // Registers built-in types
    // Custom initialization
  }

  @override
  List<E> querySync<E extends Model<dynamic>>(Request<E> req) {
    // Query local database
  }

  @override
  Future<List<E>> query<E extends Model<dynamic>>(
    Request<E> req, {Source? source}
  ) async {
    // Combine local and remote based on source
  }
}
```

### Custom Signer

```dart
class HardwareWalletSigner extends Signer {
  @override
  Future<List<E>> sign<E extends Model<dynamic>>(
    List<PartialModel<Model<dynamic>>> partialModels
  ) async {
    return Future.wait(partialModels.map((partial) async {
      if (partial is Encryptable) {
        await partial.prepareForSigning(this);
      }
      final eventId = Utils.getEventId(partial.event, pubkey);
      final signature = await _wallet.signSchnorr(eventId);
      return Model.fromPartial<E>(partial, pubkey, eventId, signature, ref);
    }));
  }
}
```

## Performance Considerations

- **Lazy Relationships**: Load on first access, not at construction
- **Metadata Caching**: Expensive computations stored in `ImmutableEvent.metadata`
- **Signature Stripping**: `keepSignatures: false` reduces storage size
- **Query Deduplication**: Relationship queries deduplicated across re-evaluations
- **Streaming Buffer**: `streamingBufferWindow` batches rapid relay events
- **Model Eviction**: `keepMaxModels` prevents unbounded growth

## Testing

**DummyStorageNotifier**: In-memory implementation for unit tests.

**DummySigner**: No-op signer for testing without cryptography. Use `partial.dummySign()` to create models with fake signatures.

**Test Data Generation**: Built-in faker integration:

```dart
final storage = container.read(storageNotifierProvider.notifier) as DummyStorageNotifier;
await storage.generateFakeProfiles(count: 10);
await storage.generateFakeFeed(authors: profiles.map((p) => p.pubkey).toSet());
```

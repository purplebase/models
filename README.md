# models 👯

Fast local-first nostr framework designed to make developers (and vibe-coders) happy. Written in Dart.

It provides:
 - Domain-specific models that wrap common nostr event kinds (with relationships between them)
 - A local-first model storage and relay interface, leveraging reactive Riverpod providers
 - Easy extensibility

> 📚 **For practical recipes and examples, check out [Purplestack](https://github.com/purplebase/purplestack)**, an agentic development stack for building Nostr-enabled Flutter applications - the best way to use this package with ready-to-use app templates and patterns.
>
> 📖 **Per-model documentation** is available in the [`docs/`](docs/) directory with detailed API references and usage examples.

An offline-ready app with reactions/zaps in a few lines of code:

```dart
Widget build(BuildContext context, WidgetRef ref) {
  final value = ref.watch(
    query<Note>(
      limit: 10,
      authors: {npub1, npub2, npub3, ...},
      and: (note) => {note.author, note.reactions, note.zaps},
    ),
  );
  // ...
  Column(children: [
    for (final note in value.models)
      NoteCard(
        userName: note.author.value!.nameOrNpub,
        noteText: note.content,
        timestamp: note.createdAt,
        likes: note.reactions.length,
        zaps: note.zaps.length,
        zapAmount: note.zaps.toList().fold(0, (acc, e) => acc += e.amount),
      )
  ])
```

Current implementations:
  - Dummy: In-memory storage and relay, for testing and prototyping (default, included)
  - [Purplebase](https://github.com/purplebase/purplebase): SQLite-powered storage and an efficient relay pool

## Features ✨

 - **Domain models**: Instead of NIP-jargon, use type-safe classes with domain language to interact with nostr, many common nostr event kinds are available (or bring your own)
 - **Relationships**: Smoothly navigate local storage with model relationships
 - **Watchable queries**: Reactive querying interface with a familiar nostr request filter API
 - **Signers**: Construct new nostr events and sign them using Amber (Android) and other NIP-55 signers available via external packages
 - **Reactive signed-in profile provider**: Keep track of signed in pubkeys and the current active user in your application
 - **Dummy implementation**: Plug-and-play implementation for testing/prototyping, easily generate dummy profiles, notes, and even a whole feed
 - **Raw events**: Access lower-level nostr event data (`event` property on all models)
 - and much more

## Installation 🛠️

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  models:
    git: # git until we put it on pub.dev
      url: https://github.com/purplebase/models
      ref: main
```

Then run `dart pub get` or `flutter pub get`.

## Table of Contents 📜

- [Core Concepts 🧠](#core-concepts-)
  - [Models & Partial Models](#models--partial-models)
  - [Relationships](#relationships)
  - [Querying](#querying)
  - [Storage & Relays](#storage--relays)
  - [Source Behavior](#source-behavior)
- [API Reference 📚](#api-reference-)
  - [Storage Configuration](#storage-configuration)
  - [Query Filters](#query-filters)
  - [Utilities](#utilities)
  - [Event Verification](#event-verification)
  - [Error Handling](#error-handling)
- [Design Notes 📝](#design-notes-)
- [Contributing 🙏](#contributing-)
- [License 📄](#license-)

## NIP Implementation Status 📋

- [x] **NIP-01: Basic protocol flow description**
- [x] **NIP-02: Follow List**
- [x] **NIP-04: Encrypted Direct Message**
- [x] **NIP-05: Mapping Nostr keys to DNS-based internet identifiers**
- [x] **NIP-09: Event Deletion Request**
- [x] **NIP-10: Text Notes and Threads**
- [x] **NIP-11: Relay Information Document**
- [x] **NIP-18: Reposts**
- [x] **NIP-19: bech32-encoded entities**
- [x] **NIP-21: `nostr:` URI scheme**
- [x] **NIP-22: Comment**
- [x] **NIP-23: Long-form Content**
- [x] **NIP-25: Reactions**
- [x] **NIP-28: Public Chat**
- [x] **NIP-29: Relay-based Groups**
- [x] **NIP-39: External Identities in Profiles**
- [x] **NIP-42: Authentication of clients to relays**
- [x] **NIP-44: Encrypted Payloads (Versioned)**
- [x] **NIP-51: Lists**
- [x] **NIP-55: Android Signer Application**
- [x] **NIP-57: Lightning Zaps**
- [x] **NIP-65: Relay List Metadata**
- [x] **NIP-72: Moderated Communities (Reddit Style)**
- [x] **NIP-78: Arbitrary custom app data**
- [x] **NIP-82: Application metadata, releases, assets** _(draft)_
- [x] **NIP-90: Data Vending Machine**
- [x] **NIP-94: File Metadata**
- [x] **NIP-47: Nostr Wallet Connect** - Complete implementation with connection management, commands, and secure storage

## Core Concepts 🧠

### Models & Partial Models

Models represent signed, immutable nostr events with domain-specific properties. Each model has a corresponding `PartialModel` for creation and signing.

```dart
// Immutable, signed model
final note = Note.fromMap(eventData, ref);
print(note.content); // Access domain properties

// Mutable, unsigned partial model for creation
final partialNote = PartialNote('Hello, nostr!');
final signedNote = await partialNote.signWith(signer);
```

**Converting Models to Partial Models:**

Models can be converted back to editable partial models using the `toPartial()` method:

```dart
// Load an existing note
final note = await ref.storage.get<Note>(noteId);

// Convert to partial for editing
final partialNote = note.toPartial<PartialNote>();

// Modify and re-sign
partialNote.content = 'Updated content';
final updatedNote = await partialNote.signWith(signer);
```

**Important Notes:**
- All public APIs work with "models" (all of which can access the underlying nostr event representation via `model.event`)
- All notifier events are already emitted sorted by `created_at` by the framework - no need to sort again

### Relationships

Models automatically establish relationships with other models:

```dart
// One-to-one relationship (BelongsTo<Profile>)
final author = note.author.value;

// One-to-many relationships (HasMany<Reaction>, HasMany<Zap>)
final reactions = note.reactions.toList();
final zaps = note.zaps.toList();
```

### Querying

Use the `query` function to reactively watch for models:

```dart
final notesState = ref.watch(
  query<Note>(
    authors: {userPubkey},
    limit: 20,
    since: DateTime.now().subtract(Duration(days: 7)),
  ),
);

// Access models and handle loading/error states
switch (notesState) {
  case StorageLoading():
    return CircularProgressIndicator();
  case StorageError():
    return Text('Error loading notes');
  case StorageData():
    return ListView.builder(
      itemCount: notesState.models.length,
      itemBuilder: (context, index) => NoteCard(notesState.models[index]),
    );
}
```

### Storage & Relays

Storage provides a unified interface for local persistence and relay communication:

```dart
// Save locally
await note.save();

// Publish to relays
await note.publish(source: RemoteSource(group: 'social'));

// Query from local storage only
final localNotes = await ref.storage.query(
  RequestFilter<Note>(authors: {pubkey}).toRequest(),
  source: LocalSource(),
);

// Query from relays only
final remoteNotes = await ref.storage.query(
  RequestFilter<Note>(authors: {pubkey}).toRequest(),
  source: RemoteSource(),
);

// Query locally and from relays in the background
final remoteNotes = await ref.storage.query(
  RequestFilter<Note>(authors: {pubkey}).toRequest(),
  source: LocalAndRemoteSource(background: true),
);
```

Note that `background: false` means waiting for EOSE. The streaming phase is always in the background.

### Source Behavior

The `Source` parameter controls where data comes from and how queries behave:

**LocalSource**: Only query local storage, never contact relays
```dart
source: LocalSource()
```

**RemoteSource**: Only query relays, never use local storage
```dart
source: RemoteSource(
  group: 'social',        // Use specific relay group (defaults to 'default')
  relayUrls: {            // Custom relay URLs (overrides group)
    'wss://custom1.relay.io',
    'wss://custom2.relay.io',
  },
  stream: true,           // Enable streaming (default)
  background: false,      // Wait for EOSE before returning
)
```

**LocalAndRemoteSource**: Query both local storage and relays
```dart
source: LocalAndRemoteSource(
  group: 'social',        // Use specific relay group (defaults to 'default')
  relayUrls: {            // Custom relay URLs (overrides group)
    'wss://priority.relay.io',
  },
  stream: true,           // Enable streaming (default)
  background: true,       // Don't wait for EOSE
)
```

**Relay Selection Priority**:
1. **`relayUrls`** - When provided, these specific relay URLs are used
2. **`group`** - Falls back to the relay group defined in `StorageConfiguration`
3. **`defaultRelayGroup`** - Uses the default group when neither is specified

This provides flexibility between:
- **Initialization-time groups**: Define stable relay collections in `StorageConfiguration.relayGroups`
- **Runtime flexibility**: Override with specific `relayUrls` for individual queries

```dart
// Use predefined relay groups (configured at initialization)
final socialNotes = ref.watch(
  query<Note>(
    authors: {pubkey},
    source: RemoteSource(group: 'social'),
  ),
);

// Override with custom relays at runtime
final privateNotes = ref.watch(
  query<Note>(
    authors: {pubkey},
    source: RemoteSource(
      relayUrls: {'wss://my-private-relay.com'},
    ),
  ),
);

// Combine local storage with custom relays
final hybridQuery = ref.watch(
  query<Note>(
    authors: {pubkey},
    source: LocalAndRemoteSource(
      relayUrls: {'wss://fast-relay.io', 'wss://backup-relay.io'},
      background: true,
    ),
  ),
);
```

**Query Behavior**:
- All queries block until local storage returns results
- If `background: false`, queries additionally block until EOSE from relays
- If `background: true`, queries return immediately after local results, relay results stream in
- The streaming phase never blocks regardless of `background` setting

## Recipes 🍳

Find detailed code examples and implementation guides for common tasks:

- **[Signer Interface & Authentication](tools/recipes/signer-interface-authentication.md)** - Set up authentication, manage multiple accounts, and handle sign-in/sign-out flows
- **[Building a Feed](tools/recipes/building-a-feed.md)** - Create reactive feeds with real-time updates and relationship loading
- **[Creating Custom Event Kinds](tools/recipes/creating-custom-event-kinds.md)** - Extend the framework with your own event types and models
- **[Using the `and` Operator for Relationships](tools/recipes/using-and-operator-relationships.md)** - Load and manage model relationships efficiently
- **[Direct Messages & Encryption](tools/recipes/direct-messages-encryption.md)** - Implement encrypted messaging with NIP-04 and NIP-44
- **[Working with DVMs (NIP-90)](tools/recipes/working-with-dvms.md)** - Integrate with Decentralized Virtual Machines for various services

## API Reference 📚

### Storage Configuration

Configure storage behavior and relay connections.

```dart
final config = StorageConfiguration(
  // Database path (null for in-memory)
  databasePath: '/path/to/database.sqlite',
  
  // Whether to keep signatures in local storage
  keepSignatures: false,
  
  // Whether to skip BIP-340 verification
  skipVerification: false,
  
  // Relay groups
  relayGroups: {
    'popular': {
      'wss://relay.damus.io',
      'wss://relay.primal.net',
    },
    'private': {
      'wss://my-private-relay.com',
    },
  },
  
  // Default relay group
  defaultRelayGroup: 'popular',
  
  // Default source for queries when not specified
  defaultQuerySource: LocalAndRemoteSource(stream: false),
  
  // Connection timeouts
  idleTimeout: Duration(minutes: 5),
  responseTimeout: Duration(seconds: 6),
  
  // Streaming configuration
  streamingBufferWindow: Duration(seconds: 2),
  
  // Storage limits
  keepMaxModels: 20000,
);
```

### Query Filters

Build complex queries with multiple conditions.

```dart
// Basic filters
final basicQuery = query<Note>(
  authors: {pubkey1, pubkey2},
  limit: 50,
  since: DateTime.now().subtract(Duration(days: 7)),
);

// Tag-based filters
final tagQuery = query<Note>(
  tags: {
    '#t': {'nostr', 'flutter'},
    '#e': {noteId},
  },
);

// Search queries
final searchQuery = query<Note>(
  search: 'hello world',
  limit: 20,
);

// Complex filters with relationships
final complexQuery = query<Note>(
  authors: {pubkey},
  kinds: {1, 6}, // Notes and reposts
  since: DateTime.now().subtract(Duration(hours: 24)),
  and: (note) => {
    note.author,
    note.reactions,
    note.zaps,
  },
);
```

### Utilities

The `Utils` class provides essential nostr-related utilities.

**Key Management:**
```dart
// Generate cryptographically secure random hex
final randomHex = Utils.generateRandomHex64();

// Derive public key from private key
final pubkey = Utils.derivePublicKey(privateKey);
```

**NIP-19 Encoding/Decoding:**
```dart
// Encode simple entities
final npub = Utils.encodeShareableFromString(pubkey, type: 'npub');
final nsec = Utils.encodeShareableFromString(privateKey, type: 'nsec');
final note = Utils.encodeShareableFromString(eventId, type: 'note');

// Decode simple entities
final decodedPubkey = Utils.decodeShareableToString(npub);
final decodedPrivateKey = Utils.decodeShareableToString(nsec); // nsec is always decoded as a string
final decodedEventId = Utils.decodeShareableToString(note);
```

**Complex Shareable Identifiers:**
```dart
// Encode complex identifiers with metadata
final profileInput = ProfileInput(
  pubkey: pubkey,
  relays: ['wss://relay.damus.io'],
  author: author,
  kind: 0,
);
final nprofile = Utils.encodeShareableIdentifier(profileInput);

final eventInput = EventInput(
  eventId: eventId,
  relays: ['wss://relay.damus.io'],
  author: author,
  kind: 1,
);
final nevent = Utils.encodeShareableIdentifier(eventInput);

final addressInput = AddressInput(
  identifier: 'my-article',
  relays: ['wss://relay.damus.io'],
  author: author,
  kind: 30023,
);
final naddr = Utils.encodeShareableIdentifier(addressInput);

// Decode complex identifiers
final profileData = Utils.decodeShareableIdentifier(nprofile) as ProfileData;
final eventData = Utils.decodeShareableIdentifier(nevent) as EventData;
final addressData = Utils.decodeShareableIdentifier(naddr) as AddressData;
```

**NIP-05 Resolution:**
```dart
// Resolve NIP-05 identifier to public key
final pubkey = await Utils.decodeNip05('alice@example.com');
```

**Event Utilities:**
```dart
// Generate event ID for partial event
final eventId = Utils.getEventId(partialEvent, pubkey);

// Check if event kind is replaceable
final isReplaceable = Utils.isEventReplaceable(kind);
```

### Event Verification

The verifier system validates BIP-340 signatures on nostr events.

**Basic Verification:**

```dart
// Get the verifier from the provider
final verifier = ref.read(verifierProvider);

// Verify an event signature
final isValid = verifier.verify(eventMap);
if (!isValid) {
  print('Event has invalid signature');
}
```

**Custom Verifier Implementation:**

```dart
class CustomVerifier extends Verifier {
  @override
  bool verify(Map<String, dynamic> map) {
    // Custom verification logic
    if (map['sig'] == null || map['sig'] == '') {
      return false;
    }
    
    // Implement your verification logic here
    return true; // or false based on verification result
  }
}

// Override the verifier provider (proper way)
ProviderScope(
  overrides: [
    verifierProvider.overrideWithValue(CustomVerifier()),
  ],
  child: MyApp(),
)
```

**Verification Configuration:**

```dart
// Enable verification (default)
final config = StorageConfiguration(
  skipVerification: false,
);

// Disable verification for performance
final config = StorageConfiguration(
  skipVerification: true,
);
```

**Verification in Storage Operations:**

```dart
// Events are automatically verified when saved (unless skipVerification: true)
await ref.storage.save({signedEvent});

// Manual verification
final verifier = ref.read(verifierProvider);
final isValid = verifier.verify(signedEvent.toMap());
```

### Error Handling

Handle storage errors and network failures gracefully.

```dart
// Watch for storage errors
ref.listen(storageNotifierProvider, (_, state) {
  if (state is StorageError) {
    print('Storage error: ${state.exception}');
    // Show error UI or retry logic
  }
});

// Handle query errors
final queryState = ref.watch(
  query<Note>(authors: {pubkey}),
);

switch (queryState) {
  case StorageError():
    return ErrorWidget(
      message: queryState.exception.toString(),
      onRetry: () {
        // Trigger a new query
        ref.invalidate(query<Note>(authors: {pubkey}));
      },
    );
  case StorageLoading():
    return LoadingWidget();
  case StorageData():
    return NotesList(notes: queryState.models);
}

// Handle network failures
try {
  await ref.storage.save({model});
} catch (e) {
  // Save locally only if remote fails
  await ref.storage.save({model});
  print('Remote save failed, saved locally: $e');
}
```

## Design Notes 📝

- Built on Riverpod providers (`storageNotifierProvider`, `query`, etc.).
- The `Storage` interface acts similarly to a relay but is optimized for local use (e.g., storing replaceable event IDs, potentially storing decrypted data, managing eviction).
- Queries (`ref.watch(query<...>(...))`) primarily interact with the local `Storage`.
- By default, queries also trigger requests to configured remote relays. Results are saved to `Storage`, automatically updating watchers.
- The system tracks query timestamps (`since`) to optimize subsequent fetches from relays.
- Relay groups can be configured and used for publishing

### Storage vs relay

A storage is very close to a relay but has some key differences, it:

 - Stores replaceable event IDs as the main ID for querying
 - Discards event signatures after validation, so not meant for rebroadcasting
 - Tracks origin relays for events, as well as connection timestamps for subsequent time-based querying
 - Has more efficient interfaces for mass deleting data
 - Can store decrypted DMs or cashu tokens, cache profile images, etc

## Contributing 📩

Contributions are welcome. However, please open an issue to discuss your proposed changes *before* starting work on a pull request.

## License 📄

MIT
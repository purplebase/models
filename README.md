# models 👯

Fast local-first nostr framework designed to make developers (and vibe-coders) happy. Written in Dart.

It provides:
 - Domain-specific models that wrap common nostr event kinds (with relationships between them)
 - A local-first model storage and relay interface, leveraging reactive Riverpod providers
 - Built-in Nostr relay server for testing and development
 - Complete NostrWalletConnect (NWC) implementation for Lightning payments
 - Comprehensive authentication and signer management
 - Event verification and cryptographic operations
 - Easy extensibility

> 📚 **For practical recipes and examples, check out [Purplestack](https://github.com/purplebase/purplestack)**, an agentic development stack for building Nostr-enabled Flutter applications - the best way to use this package with ready-to-use app templates and patterns.

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
 - **Reactive querying**: Multiple query providers for different use cases with familiar nostr request filter API
 - **Built-in relay server**: In-memory Nostr relay suitable for development and testing
 - **NostrWalletConnect**: Complete NIP-47 implementation for Lightning wallet integration
 - **Signers & Authentication**: Construct new nostr events and sign them using Amber (Android) and other NIP-55 signers, with comprehensive authentication management
 - **Event verification**: Built-in BIP-340 signature verification with configurable verifiers
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
  - [Querying & Providers](#querying--providers)
  - [Storage & Relays](#storage--relays)
  - [Source Behavior](#source-behavior)
- [Authentication & Signers 🔐](#authentication--signers-)
  - [Signer Providers](#signer-providers)
  - [Authentication Management](#authentication-management)
- [Built-in Relay Server 🖥️](#built-in-relay-server-)
- [NostrWalletConnect 💰](#nostrwalletconnect-)
- [API Reference 📚](#api-reference-)
  - [Query Providers](#query-providers)
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
- [x] **NIP-47: Nostr Wallet Connect** - Complete implementation with connection management, commands, and secure storage
- [x] **NIP-51: Lists**
- [x] **NIP-55: Android Signer Application**
- [x] **NIP-57: Lightning Zaps**
- [x] **NIP-65: Relay List Metadata**
- [x] **NIP-71: Video Events**
- [x] **NIP-72: Moderated Communities (Reddit Style)**
- [x] **NIP-78: Arbitrary custom app data**
- [x] **NIP-82: Application metadata, releases, assets** _(draft)_
- [x] **NIP-90: Data Vending Machine**
- [x] **NIP-94: File Metadata**
- [x] **NIP-A0: Voice Messages**

## Registered Event Kinds 📋

This table lists all Nostr event kinds currently registered in this library to help developers avoid conflicts when implementing custom models:

| Kind | Model Class | NIP | Description | Type |
|------|-------------|-----|-------------|------|
| 0 | `Profile` | NIP-01 | User Metadata | Replaceable |
| 1 | `Note` | NIP-01 | Short Text Note | Regular |
| 3 | `ContactList` | NIP-02 | Follow List | Replaceable |
| 4 | `DirectMessage` | NIP-04 | Encrypted Direct Message | Regular |
| 5 | `EventDeletionRequest` | NIP-09 | Event Deletion Request | Regular |
| 6 | `Repost` | NIP-18 | Repost | Regular |
| 7 | `Reaction` | NIP-25 | Reaction | Regular |
| 9 | `ChatMessage` | NIP-28 | Chat Message | Regular |
| 11 | `RelayInfo` | NIP-11 | Relay Information Document | Regular |
| 16 | `GenericRepost` | NIP-18 | Generic Repost | Regular |
| 20 | `Picture` | NIP-68 | Picture Event | Regular |
| 21 | `Video` | NIP-71 | Video Event | Regular |
| 22 | `ShortFormPortraitVideo` | NIP-71 | Short-form Portrait Video Event | Regular |
| 1063 | `FileMetadata` | NIP-94 | File Metadata | Regular |
| 1111 | `Comment` | NIP-22 | Comment | Regular |
| 1222 | `VoiceMessage` | NIP-A0 | Voice Message | Regular |
| 1244 | `VoiceMessageComment` | NIP-A0 | Voice Message Comment | Regular |
| 1984 | `Report` | NIP-56 | Content Report | Regular |
| 3063 | `SoftwareAsset` | NIP-82 | Software Asset | Regular |
| 5312 | `VerifyReputationRequest` | NIP-90 | DVM Request | Regular |
| 6312 | `VerifyReputationResponse` | NIP-90 | DVM Response | Regular |
| 7000 | `DVMError` | NIP-90 | DVM Error | Regular |
| 9734 | `ZapRequest` | NIP-57 | Zap Request | Regular |
| 9735 | `Zap` | NIP-57 | Zap Receipt | Regular |
| 9802 | `Highlight` | NIP-84 | Highlight | Regular |
| 10000 | `MuteList` | NIP-51 | Mute List | Replaceable |
| 10001 | `PinList` | NIP-51 | Pin List | Replaceable |
| 10002 | `RelayListMetadata` | NIP-65 | Relay List Metadata | Replaceable |
| 10003 | `BookmarkList` | NIP-51 | Bookmark List | Replaceable |
| 10222 | `Community` | NIP-72 | Community Definition | Replaceable |
| 13194 | `NwcInfo` | NIP-47 | NWC Wallet Info | Regular |
| 23194 | `NwcRequest` | NIP-47 | NWC Request | Regular |
| 23195 | `NwcResponse` | NIP-47 | NWC Response | Regular |
| 23196 | `NwcNotification` | NIP-47 | NWC Notification | Regular |
| 24133 | `BunkerAuthorization` | NIP-46 | Bunker Authorization | Ephemeral |
| 24242 | `BlossomAuthorization` | Blossom | Blossom Authorization | Ephemeral |
| 30000 | `FollowSets` | NIP-51 | Follow Sets | Parameterizable |
| 30023 | `Article` | NIP-23 | Long-form Content | Parameterizable |
| 30063 | `Release` | NIP-82 | Software Release | Parameterizable |
| 30078 | `CustomData` | NIP-78 | Application Data | Parameterizable |
| 30222 | `TargetedPublication` | NIP-72 | Targeted Publication | Parameterizable |
| 30267 | `AppCurationSet` | NIP-89 | App Curation Set | Parameterizable |
| 31922 | `DateBasedCalendarEvent` | NIP-52 | Date-Based Calendar Event | Parameterizable |
| 31923 | `TimeBasedCalendarEvent` | NIP-52 | Time-Based Calendar Event | Parameterizable |
| 31924 | `Calendar` | NIP-52 | Calendar Collection | Parameterizable |
| 31925 | `CalendarEventRSVP` | NIP-52 | Calendar Event RSVP | Parameterizable |
| 32267 | `App` | NIP-89 | Application Metadata | Parameterizable |

> **Note**: When implementing custom models, choose unused kind numbers to avoid conflicts. Regular events use kinds 1000-9999, Replaceable events use 10000-19999, and Parameterizable Replaceable events use 30000-39999 per NIP-01 conventions.

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
// Load an existing note by ID from local storage
final note = (await ref.storage.query(
  RequestFilter<Note>(ids: {noteId}).toRequest(),
  source: LocalSource(),
)).first;

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

#### Dynamic Nested Relationships

The `and` parameter supports dynamic nested relationships that are automatically discovered as related models arrive. This enables powerful patterns for loading deeply connected data:

```dart
// Load apps with their releases and file metadata
final appsState = ref.watch(
  query<App>(
    limit: 20,
    and: (app) => {
      app.latestRelease,
      // Nested: load metadata when release arrives
      if (app.latestRelease.value != null)
        app.latestRelease.value!.latestMetadata,
    },
  ),
);

// Load notes with author profiles and their contact lists
final notesState = ref.watch(
  query<Note>(
    limit: 50,
    and: (note) => {
      note.author,
      // Nested: load contact list when author arrives
      if (note.author.value != null)
        note.author.value!.contactList,
    },
  ),
);
```

**How it works:**
1. When primary models (e.g., Apps) first arrive, the `and` function evaluates and discovers direct relationships
2. As each relationship resolves (e.g., Release arrives), the `and` function re-evaluates on primary models
3. New conditional branches become available (e.g., `if (app.latestRelease.value != null)`), discovering nested relationships
4. This continues recursively for any depth, with automatic deduplication preventing redundant queries

**Key features:**
- **Automatic cascading**: Relationships discovered at any nesting level
- **Conditional loading**: Use `if` checks to load relationships only when available
- **Efficient**: Deduplication ensures each relationship is queried only once
- **Event-driven**: Re-evaluation only happens when relationship data arrives
- **No infinite loops**: Built-in safeguards prevent circular reference issues

### Querying & Providers

The framework provides multiple reactive query providers for different use cases:

#### Typed Query Provider (`query<E>`)

Query specific model types with full type safety:

```dart
final notesState = ref.watch(
  query<Note>(
    authors: {userPubkey},
    limit: 20,
    since: DateTime.now().subtract(Duration(days: 7)),
    and: (note) => {note.author, note.reactions, note.zaps}, // Load relationships
  ),
);

// Access typed models
switch (notesState) {
  case StorageLoading():
    return CircularProgressIndicator();
  case StorageError():
    return Text('Error loading notes');
  case StorageData(:final models):
    return ListView.builder(
      itemCount: models.length,
      itemBuilder: (context, index) => NoteCard(models[index]),
    );
}
```

#### Generic Query Provider (`queryKinds`)

Query events across multiple kinds without type constraints:

```dart
final multiKindState = ref.watch(
  queryKinds(
    kinds: {1, 6}, // Notes and reposts
    authors: {userPubkey},
    limit: 20,
    since: DateTime.now().subtract(Duration(days: 7)),
  ),
);

// Access models and handle loading/error states
switch (multiKindState) {
  case StorageLoading():
    return CircularProgressIndicator();
  case StorageError():
    return Text('Error loading events');
  case StorageData(:final models):
    return ListView.builder(
      itemCount: models.length,
      itemBuilder: (context, index) => EventCard(models[index]),
    );
}
```

#### Single Model Provider (`model<E>`)

Watch a specific model instance for updates:

```dart
final noteState = ref.watch(
  model<Note>(
    existingNote,
    and: (note) => {note.author, note.reactions, note.zaps},
  ),
);

// The provider automatically updates when the model changes
final note = noteState.models.firstOrNull;
if (note != null) {
  return NoteDetailCard(note);
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
  background: true,       // Don't wait for EOSE to return
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
- All queries return local results first
- **`stream: true`** - Keep subscription open for new events
  - `background: true` - Return immediately with local results, fetch remote in background
  - `background: false` - Wait for EOSE before returning, then continue streaming
- **`stream: false`** - One-time fetch (always waits for EOSE, ignores `background` flag)
- The streaming phase never blocks regardless of `background` setting

**Common Patterns**:
```dart
// Real-time feed with immediate response
source: LocalAndRemoteSource(stream: true, background: true)

// Wait for initial data then stream updates
source: RemoteSource(stream: true, background: false)

// One-time fetch (no ongoing updates)
source: RemoteSource(stream: false)  // background flag is ignored
```

## Authentication & Signers 🔐

### Signer Providers

The framework provides comprehensive signer and authentication management through reactive providers:

#### Active Signer Management

```dart
// Get the currently active signer
final activeSigner = ref.watch(Signer.activeSignerProvider);
if (activeSigner != null) {
  final signedEvents = await activeSigner.sign([partialNote]);
}

// Get the active user's pubkey
final activePubkey = ref.watch(Signer.activePubkeyProvider);

// Get the active user's profile
final activeProfile = ref.watch(
  Signer.activeProfileProvider(LocalAndRemoteSource()),
);
```

#### Multi-User Support

```dart
// Get all signed-in pubkeys
final signedInPubkeys = ref.watch(Signer.signedInPubkeysProvider);

// Get a specific signer by pubkey
final specificSigner = ref.watch(Signer.signerProvider(pubkey));

// Check if a user is signed in
final isSignedIn = signedInPubkeys.contains(somePubkey);
```

### Authentication Management

```dart
// Sign in a user (makes them active by default)
await signer.signIn(setAsActive: true);

// Sign in without making active
await signer.signIn(setAsActive: false);

// Sign in without registering (for external signers that handle their own registration)
await signer.signIn(setAsActive: true, registerSigner: false);

// Set as active signer
signer.setAsActivePubkey();

// Sign out user
await signer.signOut();

// Remove from active (but keep signed in)
signer.removeAsActivePubkey();

// Check sign-in status
final isSignedIn = signer.isSignedIn;
```

## Built-in Relay Server 🖥️

The framework includes an in-memory Nostr relay intended for development and testing:

### Running the Relay

```bash
# Run with default settings (port 8080, all interfaces)
dart run models:dart_relay

# Custom port and host
dart run models:dart_relay --port 7777 --host localhost

# See all options
dart run models:dart_relay --help
```

### Programmatic Usage

```dart
final container = ProviderContainer();

// Provide a ref to the relay
final refProvider = Provider((ref) => ref);

final relay = NostrRelay(
  port: 8080,
  host: '0.0.0.0',
  ref: container.read(refProvider),
);

// Start the relay
await relay.start();
print('Relay running on ws://localhost:8080');

// Stop the relay
await relay.stop();
```

### Relay Features

- **WebSocket support**: Full Nostr protocol implementation
- **Memory storage**: Fast in-memory event storage
- **Real-time subscriptions**: Live event streaming
- **NIP compliance**: Supports core Nostr NIPs
- **Dev-focused**: Designed for development and testing environments

## NostrWalletConnect 💰

Complete implementation of NIP-47 for Lightning wallet integration:

```dart
// Pay a Lightning invoice using high-level API
await signer.pay('lnbc...', amount: 1000);
```

## Recipes 🍳

See examples and patterns in Purplestack.

## API Reference 📚

### Query Providers

The framework provides three main query providers for different use cases:

#### `query<E>()` - Typed Queries
- **Returns**: `AutoDisposeStateNotifierProvider<RequestNotifier<E>, StorageState<E>>`
- **Purpose**: Query specific model types with full type safety
- **Models accessible as**: `state.models (List<E>)`

#### `queryKinds()` - Multi-Kind Queries  
- **Returns**: `AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>`
- **Purpose**: Query events across multiple kinds without type constraints
- **Models accessible as**: `state.models (List<Model<dynamic>>)`

#### `model<E>()` - Single Model Watching
- **Returns**: `AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>`
- **Purpose**: Watch a specific model instance for updates
- **Model accessible as**: `state.models.firstOrNull`

#### Provider Usage Patterns

```dart
// Watch with error handling
final notesState = ref.watch(query<Note>(authors: {pubkey}));
switch (notesState) {
  case StorageLoading():
    return CircularProgressIndicator();
  case StorageError(:final exception):
    return ErrorWidget(exception.toString());
  case StorageData(:final models):
    return NotesList(models);
}

// Listen for changes
ref.listen(query<Note>(authors: {pubkey}), (previous, next) {
  if (next is StorageData && previous is StorageLoading) {
    print('Notes loaded: ${next.models.length}');
  }
});

// One-time read
final currentState = ref.read(query<Note>(authors: {pubkey}));
```

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
// Manual verification example
final verifier = ref.read(verifierProvider);
final isValid = verifier.verify(signedEvent.toMap());
```

Note: Verification is provided via `verifierProvider`. Storage implementations may choose how to use it.

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
  case StorageData(:final models):
    return NotesList(notes: models);
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
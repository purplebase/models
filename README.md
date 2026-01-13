# models

A local-first Nostr framework for Dart applications. Built on Riverpod for reactive state management.

## Overview

This library provides domain-driven abstractions over the Nostr protocol, enabling developers to work with typed models (`Note`, `Profile`, `Reaction`) rather than raw JSON events. Key features:

- **Domain models** wrapping common Nostr event kinds with relationships between them
- **Local-first storage** with background relay synchronization via Riverpod providers
- **NIP-44 encryption** for direct messages and private data
- **NostrWalletConnect (NIP-47)** for Lightning payments
- **Signer management** supporting multiple authentication methods
- **BIP-340 signature verification**

For practical examples and application templates, see [Purplestack](https://github.com/purplebase/purplestack).

### Quick Example

```dart
Widget build(BuildContext context, WidgetRef ref) {
  final state = ref.watch(
    query<Note>(
      limit: 10,
      authors: {npub1, npub2, npub3},
      and: (note) => {note.author.query(), note.reactions.query(), note.zaps.query()},
    ),
  );

  return switch (state) {
    StorageLoading() => CircularProgressIndicator(),
    StorageError(:final exception) => Text('Error: $exception'),
    StorageData(:final models) => ListView(
      children: [
        for (final note in models)
          NoteCard(
            userName: note.author.value!.nameOrNpub,
            noteText: note.content,
            likes: note.reactions.length,
            zapAmount: note.zaps.fold(0, (acc, z) => acc + z.amount),
          )
      ],
    ),
  };
}
```

## Installation

```yaml
dependencies:
  models:
    git:
      url: https://github.com/purplebase/models
      ref: main
```

## Core Concepts

### Models and Partial Models

Models are immutable, signed Nostr events with domain-specific properties. `PartialModel` instances are mutable and unsigned, used for event creation.

```dart
// Create and sign a new note
final partial = PartialNote('Hello, Nostr!');
final note = await partial.signWith(signer);
await note.save();

// Convert existing model back to partial for editing
final editableNote = existingNote.toPartial<PartialNote>();
editableNote.content = 'Updated content';
final updated = await editableNote.signWith(signer);
```

### Relationships

Models establish typed relationships with other models:

```dart
// BelongsTo: single related model
final author = note.author.value;

// HasMany: collection of related models
final reactions = note.reactions.toList();
final zaps = note.zaps.toList();
```

Relationships support nested loading via the `and` parameter, which returns `NestedQuery` descriptors:

```dart
final state = ref.watch(
  query<App>(
    limit: 20,
    and: (app) => {
      app.latestRelease.query(),
      app.author.query(source: RemoteSource(relays: {'social'})),
    },
  ),
);
```

### Querying

Three query providers cover different use cases:

**`query<E>()`** - Typed queries with full type safety:

```dart
final notes = ref.watch(
  query<Note>(
    authors: {pubkey1, pubkey2},
    limit: 50,
    since: DateTime.now().subtract(Duration(days: 7)),
    tags: {'#t': {'nostr', 'dart'}},
    and: (note) => {note.author.query(), note.reactions.query()},
  ),
);
```

**`queryKinds()`** - Multi-kind queries without type constraints:

```dart
final mixed = ref.watch(
  queryKinds(
    kinds: {1, 6}, // Notes and reposts
    authors: {pubkey},
    limit: 20,
  ),
);
```

**`model<E>()`** - Watch a specific model instance:

```dart
final noteState = ref.watch(
  model<Note>(existingNote, and: (n) => {n.author.query(), n.reactions.query()}),
);
```

### Source Control

The `Source` parameter determines where data comes from:

```dart
// Local storage only
source: LocalSource()

// Relays only - by label
source: RemoteSource(
  relays: 'AppCatalog',  // Looks up RelayList by label
  stream: true
)

// Relays only - ad-hoc URL
source: RemoteSource(
  relays: 'wss://relay.damus.io',  // Direct relay URL
)

// Both local and remote
source: LocalAndRemoteSource(
  relays: 'AppCatalog',  // Uses the AppCatalog relay set
  stream: true
)
```

Default relays are configured in `StorageConfiguration`:

```dart
StorageConfiguration(
  defaultRelays: {
    'social': {'wss://relay.damus.io', 'wss://relay.primal.net'},
    'AppCatalog': {'wss://relay.zapstore.dev'},
  },
)
```

The `relays` parameter accepts:
- **Relay URL** (starts with `ws://` or `wss://`): Used directly as ad-hoc relay
- **Label**: Looks up a `RelayList` by label (e.g., 'AppCatalog' → kind 10067)
- **null**: TODO - will implement outbox lookup (NIP-65)

Each relationship can specify its own source:

```dart
ref.watch(
  query<Note>(
    authors: {pubkey},
    source: RemoteSource(stream: false),      // One-time fetch for notes
    and: (note) => {
      note.author.query(source: RemoteSource(stream: true)),  // Keep profile streaming
    },
  ),
);
```

### Caching

For queries consisting only of author and/or replaceable kinds, `cachedFor` returns local data without querying remote for the specified duration:

```dart
// Use cached profile for 5 minutes
query<Profile>(
  authors: {pubkey},
  source: LocalAndRemoteSource(cachedFor: Duration(minutes: 5)),
)
```

Caching is silently ignored if the query has other filter fields (tags, ids, search, until).

### Filtering

Two filtering options are available:

**`schemaFilter`** - Applied to raw events *before* model construction. More efficient but can only access raw event data:

```dart
// Discard short notes before constructing models
query<Note>(
  authors: {pubkey},
  schemaFilter: (event) => (event['content'] as String).length > 10,
)
```

**`where`** - Applied to models *after* construction. Can access relationships and computed properties:

```dart
// Filter by relationship data
final verified = ref.watch(
  query<Note>(
    authors: allAuthors,
    where: (note) => note.author.value?.nip05 != null,
    and: (note) => {note.author.query()},
  ),
);

// Filter by computed properties
final bigZaps = ref.watch(
  query<Zap>(
    limit: 100,
    where: (zap) => zap.amount > 10000,
  ),
);
```

Always use Nostr filters to reduce the dataset before applying `where` for optimal performance.

## Authentication and Signers

### Signer Types

```dart
// BIP-340 private key signer (real signing)
final signer = Bip340PrivateKeySigner(privateKeyHex, ref);
await signer.signIn();

// Dummy signer for testing
final dummy = DummySigner(ref);
await dummy.signIn();
```

### Signer Providers

```dart
// Active signer
final signer = ref.watch(Signer.activeSignerProvider);

// Active user's pubkey
final pubkey = ref.watch(Signer.activePubkeyProvider);

// Active user's profile
final profile = ref.watch(Signer.activeProfileProvider(LocalAndRemoteSource()));

// All signed-in pubkeys
final pubkeys = ref.watch(Signer.signedInPubkeysProvider);

// Specific signer by pubkey
final specific = ref.watch(Signer.signerProvider(pubkey));
```

### Authentication Management

```dart
await signer.signIn(setAsActive: true);
await signer.signOut();
signer.setAsActivePubkey();
signer.removeAsActivePubkey();
```

## Encryption

Content is plaintext before signing and encrypted during the signing process. After signing, content remains encrypted locally and on relays.

```dart
// Create with plaintext
final partial = PartialAppStack.withEncryptedApps(
  name: 'Dev Tools',
  identifier: 'dev',
  apps: ['32267:pubkey:vscode'],
);

// Sign encrypts the content
final appStack = await partial.signWith(signer);

// To read, explicitly decrypt
final decrypted = await signer.nip44Decrypt(appStack.content, signer.pubkey);
```

Models supporting encryption:
- `DirectMessage` (NIP-44)
- `AppStack`, `BookmarkSet`, `FollowSets`, `MuteList`, `PinList`
- `NwcRequest`, `NwcResponse`, `NwcNotification` (NIP-47)

## NostrWalletConnect

Complete NIP-47 implementation for Lightning payments:

```dart
await signer.pay('lnbc...', amount: 1000);
```

## Storage Configuration

```dart
final config = StorageConfiguration(
  databasePath: '/path/to/database.sqlite',
  keepSignatures: false,
  skipVerification: false,
  defaultRelays: {
    'default': {'wss://relay.damus.io', 'wss://nos.lol'},
  },
  defaultQuerySource: LocalAndRemoteSource(stream: false),
  idleTimeout: Duration(minutes: 5),
  responseTimeout: Duration(seconds: 4),
  streamingBufferDuration: Duration(seconds: 2),
  keepMaxModels: 20000,
);
```

## Storage Implementations

- **DummyStorageNotifier**: In-memory storage for testing and prototyping (included)
- **[Purplebase](https://github.com/purplebase/purplebase)**: SQLite-powered storage with relay pool

## Utilities

```dart
// Key management
final randomHex = Utils.generateRandomHex64();
final pubkey = Utils.derivePublicKey(privateKey);

// NIP-19 encoding/decoding
final npub = Utils.encodeShareableFromString(pubkey, type: 'npub');
final decoded = Utils.decodeShareableToString(npub);

// Complex shareable identifiers
final nprofile = Utils.encodeShareableIdentifier(
  ProfileInput(pubkey: pubkey, relays: ['wss://relay.damus.io']),
);
final data = Utils.decodeShareableIdentifier(nprofile) as ProfileData;

// NIP-05 resolution
final pubkey = await Utils.decodeNip05('alice@example.com');
```

## Verification

```dart
final verifier = ref.read(verifierProvider);
final isValid = verifier.verify(eventMap);
```

Verification can be disabled for performance:

```dart
StorageConfiguration(skipVerification: true)
```

## NIP Implementation Status

| NIP | Description | Status |
|-----|-------------|--------|
| 01 | Basic protocol flow | Implemented |
| 02 | Follow List | Implemented |
| 04 | Encrypted Direct Message | Deprecated (use NIP-44) |
| 05 | DNS identifiers | Implemented |
| 09 | Event Deletion | Implemented |
| 10 | Text Notes and Threads | Implemented |
| 11 | Relay Information | Implemented |
| 18 | Reposts | Implemented |
| 19 | bech32 entities | Implemented |
| 21 | `nostr:` URI scheme | Implemented |
| 22 | Comment | Implemented |
| 23 | Long-form Content | Implemented |
| 25 | Reactions | Implemented |
| 28 | Public Chat | Implemented |
| 29 | Relay-based Groups | Implemented |
| 39 | External Identities | Implemented |
| 42 | Client Authentication | Implemented |
| 44 | Encrypted Payloads | Implemented |
| 47 | Wallet Connect | Implemented |
| 51 | Lists | Implemented |
| 55 | Android Signer | Implemented |
| 57 | Lightning Zaps | Implemented |
| 65 | Relay List Metadata | Implemented |
| 71 | Video Events | Implemented |
| 72 | Communities | Implemented |
| 78 | App Data | Implemented |
| 82 | Application Metadata | Implemented (draft) |
| 90 | Data Vending Machine | Implemented |
| 94 | File Metadata | Implemented |
| A0 | Voice Messages | Implemented |

## Registered Event Kinds

| Kind | Model | Type |
|------|-------|------|
| 0 | `Profile` | Replaceable |
| 1 | `Note` | Regular |
| 3 | `ContactList` | Replaceable |
| 4 | `DirectMessage` | Regular |
| 5 | `EventDeletionRequest` | Regular |
| 6 | `Repost` | Regular |
| 7 | `Reaction` | Regular |
| 9 | `ChatMessage` | Regular |
| 16 | `GenericRepost` | Regular |
| 20 | `Picture` | Regular |
| 21 | `Video` | Regular |
| 22 | `ShortFormPortraitVideo` | Regular |
| 1063 | `FileMetadata` | Regular |
| 1111 | `Comment` | Regular |
| 1222 | `VoiceMessage` | Regular |
| 1244 | `VoiceMessageComment` | Regular |
| 1984 | `Report` | Regular |
| 3063 | `SoftwareAsset` | Regular |
| 5312 | `VerifyReputationRequest` | Regular |
| 6312 | `VerifyReputationResponse` | Regular |
| 7000 | `DVMError` | Regular |
| 9734 | `ZapRequest` | Regular |
| 9735 | `Zap` | Regular |
| 9802 | `Highlight` | Regular |
| 10000 | `MuteList` | Replaceable |
| 10001 | `PinList` | Replaceable |
| 10002 | `SocialRelayList` | Replaceable |
| 10067 | `AppCatalogRelayList` | Replaceable |
| 10222 | `Community` | Replaceable |
| 13194 | `NwcInfo` | Regular |
| 23194 | `NwcRequest` | Regular |
| 23195 | `NwcResponse` | Regular |
| 23196 | `NwcNotification` | Regular |
| 24133 | `BunkerAuthorization` | Ephemeral |
| 24242 | `BlossomAuthorization` | Ephemeral |
| 30000 | `FollowSets` | Parameterizable |
| 30003 | `BookmarkSet` | Parameterizable |
| 30023 | `Article` | Parameterizable |
| 30063 | `Release` | Parameterizable |
| 30078 | `CustomData` | Parameterizable |
| 30222 | `TargetedPublication` | Parameterizable |
| 30267 | `AppStack` | Parameterizable |
| 31922 | `DateBasedCalendarEvent` | Parameterizable |
| 31923 | `TimeBasedCalendarEvent` | Parameterizable |
| 31924 | `Calendar` | Parameterizable |
| 31925 | `CalendarEventRSVP` | Parameterizable |
| 32267 | `App` | Parameterizable |

When implementing custom models, choose unused kind numbers. Per NIP-01 conventions: regular events use 1000-9999, replaceable use 10000-19999, parameterizable replaceable use 30000-39999.

## Design Notes

- Built on Riverpod providers (`storageNotifierProvider`, `query`, etc.)
- The `Storage` interface optimizes for local use: stores replaceable event IDs, manages eviction, tracks origin relays
- Queries primarily interact with local storage; remote relay requests are triggered by default and results are saved locally
- Relay groups can be configured for publishing to different relay sets

### Storage vs Relay

Storage differs from a relay in several ways:

- Stores replaceable event IDs as the main ID for querying
- Optionally discards signatures after validation (not meant for rebroadcasting)
- Tracks origin relays and connection timestamps for time-based querying
- Provides efficient interfaces for mass deletion
- Can store decrypted content, cache images, etc.

## Contributing

Contributions are welcome. Please open an issue to discuss proposed changes before starting work on a pull request.

## License

MIT

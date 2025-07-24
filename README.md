# models 👯

Fast local-first nostr framework designed to make developers (and vibe-coders) happy. Written in Dart.

It provides:
 - Domain-specific models that wrap common nostr event kinds (with relationships between them)
 - A local-first model storage and relay interface, leveraging reactive Riverpod providers
 - Easy extensibility

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
  - Dummy: In-memory storage and relay fetch simulation, for testing and prototyping (default, included)
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
      ref: 0.1.0
```

Then run `dart pub get` or `flutter pub get`.

## Table of Contents 📜

- [Quickstart 🚀](#quickstart-)
- [Core Concepts 🧠](#core-concepts-)
  - [Models & Partial Models](#models--partial-models)
  - [Relationships](#relationships)
  - [Querying](#querying)
  - [Storage & Relays](#storage--relays)
  - [Source Behavior](#source-behavior)
- [Recipes 🍳](#recipes-)
  - [Signer Interface & Authentication](#signer-interface--authentication)
  - [Building a Feed](#building-a-feed)
  - [Creating Custom Event Kinds](#creating-custom-event-kinds)
  - [Using the `and` Operator for Relationships](#using-the-and-operator-for-relationships)
  - [Direct Messages & Encryption](#direct-messages--encryption)
  - [Working with DVMs (NIP-90)](#working-with-dvms-nip-90)
- [API Reference 📚](#api-reference-)
  - [Storage Configuration](#storage-configuration)
  - [Query Filters](#query-filters)
  - [Model Types](#model-types)
  - [Utilities](#utilities)
  - [Event Verification](#event-verification)
  - [Error Handling](#error-handling)
- [Design Notes 📝](#design-notes-)
- [Contributing 🙏](#contributing-)
- [License 📄](#license-)

## Quickstart 🚀

Here is a minimal Flutter/Riverpod app that shows a user's notes and replies.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';

void main() => runApp(ProviderScope(child: MaterialApp(home: NotesScreen())));

class NotesScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(initializationProvider(StorageConfiguration()))) {
      AsyncLoading() => Center(child: CircularProgressIndicator()),
      AsyncError() => Center(child: Text('Error initializing')),
      _ => Scaffold(
        body: Consumer(
          builder: (context, ref, _) {
            final activePubkey = ref.watch(Signer.activePubkeyProvider);
            if (activePubkey == null) {
              return Center(child: Text('Please sign in'));
            }
            
            final notesState = ref.watch(
              query<Note>(
                authors: {activePubkey},
                limit: 100,
                and: (note) => {
                  note.author,      // Include author profile
                  note.reactions,   // Include reactions
                  note.zaps,        // Include zaps
                  note.root,        // Include root note for replies
                  note.replies,     // Include direct replies
                },
              ),
            );
            
            return switch (notesState) {
              StorageLoading() => Center(child: CircularProgressIndicator()),
              StorageError() => Center(child: Text('Error loading notes')),
              StorageData() => ListView.builder(
                itemCount: notesState.models.length,
                itemBuilder: (context, index) {
                  final note = notesState.models[index];
                  return NoteCard(note: note);
                },
              ),
            };
          },
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () async {
            final signer = ref.read(Signer.activeSignerProvider);
            if (signer != null) {
              final newNote = await PartialNote('Hello, nostr!').signWith(signer);
              await ref.storage.save({newNote});
            }
          },
        ),
      ),
    };
  }
}

class NoteCard extends StatelessWidget {
  final Note note;
  
  const NoteCard({required this.note, super.key});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(
                    note.author.value?.pictureUrl ?? '',
                  ),
                ),
                SizedBox(width: 8),
                Text(note.author.value?.nameOrNpub ?? 'Unknown'),
              ],
            ),
            SizedBox(height: 8),
            
            // Note content
            Text(note.content),
            SizedBox(height: 8),
            
            // Reply indicator
            if (note.root.value != null)
              Text('↳ Reply to ${note.root.value!.author.value?.nameOrNpub ?? 'Unknown'}'),
            
            // Engagement metrics
            Row(
              children: [
                Icon(Icons.favorite, size: 16),
                Text('${note.reactions.length}'),
                SizedBox(width: 16),
                Icon(Icons.flash_on, size: 16),
                Text('${note.zaps.length}'),
                SizedBox(width: 16),
                Icon(Icons.reply, size: 16),
                Text('${note.replies.length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

**Flutter Syntax Sugar** (Optional): For Flutter apps, you can add this extension for cleaner syntax:

```dart
extension WidgetRefStorage on WidgetRef {
  StorageNotifier get storage => read(storageNotifierProvider.notifier);
}
```

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

### Signer Interface & Authentication

The signer system manages authentication and signing across your app.

**Basic Signer Setup:**

```dart
// Create a private key signer
final privateKey = 'your_private_key_here';
final signer = Bip340PrivateKeySigner(privateKey, ref);

// Sign in (sets the pubkey as active)
await signer.signIn();

// Check if signer is signed in and available for use
final isSignedIn = signer.isSignedIn;
final isAvailable = await signer.isAvailable;

// Watch the active profile (use RemoteSource() if you want to fetch from relays)
final activeProfile = ref.watch(Signer.activeProfileProvider(LocalSource()));
final activePubkey = ref.watch(Signer.activePubkeyProvider);
```

**Multiple Account Management:**

```dart
// Sign in multiple accounts
final signer1 = Bip340PrivateKeySigner(privateKey1, ref);
final signer2 = Bip340PrivateKeySigner(privateKey2, ref);

await signer1.signIn(setAsActive: false); // Don't set as active
await signer2.signIn(setAsActive: true);  // Set as active

// Switch between accounts
await signer1.setAsActivePubkey();
await signer2.removeAsActivePubkey();

// Get all signed-in accounts
final signedInPubkeys = ref.watch(Signer.signedInPubkeysProvider);
```

**Active Profile with Different Sources:**

```dart
// Get active profile from local storage only
final localProfile = ref.watch(Signer.activeProfileProvider(LocalSource()));

// Get active profile from local storage and relays
final fullProfile = ref.watch(Signer.activeProfileProvider(LocalAndRemoteSource()));

// Get active profile from specific relay group
final socialProfile = ref.watch(Signer.activeProfileProvider(
  RemoteSource(group: 'social'),
));
```

The [amber_signer](https://github.com/purplebase/amber_signer) package implements this interface for Amber / NIP-55.

**Sign Out Flow:**

```dart
// Clean up when user signs out
await signer.signOut();

// The active profile provider will automatically update
// as the signer is removed from the system
```

### Building a Feed

Create a reactive feed that updates in real-time.

**Home Feed with Relationships:**

```dart
class HomeFeed extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProfile = ref.watch(Signer.activeProfileProvider(LocalSource()));
    
    if (activeProfile == null) {
      return Center(child: Text('Please sign in'));
    }
    
    // Get following pubkeys from contact list
    final following = activeProfile.contactList.value?.followingPubkeys ?? {};
    
    final feedState = ref.watch(
      query<Note>(
        authors: following,
        limit: 50,
        and: (note) => {
          note.author,           // Include author profile
          note.reactions,        // Include reactions
          note.zaps,            // Include zaps
          note.root,            // Include root note for replies
        },
      ),
    );
    
    return switch (feedState) {
      StorageLoading() => Center(child: CircularProgressIndicator()),
      StorageError() => Center(child: Text('Error loading feed')),
      StorageData() => ListView.builder(
        itemCount: feedState.models.length,
        itemBuilder: (context, index) {
          final note = feedState.models[index];
          return FeedItemCard(note: note);
        },
      ),
    };
  }
}

class FeedItemCard extends StatelessWidget {
  final Note note;
  
  const FeedItemCard({required this.note, super.key});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(
                    note.author.value?.pictureUrl ?? '',
                  ),
                ),
                SizedBox(width: 8),
                Text(note.author.value?.nameOrNpub ?? 'Unknown'),
              ],
            ),
            SizedBox(height: 8),
            
            // Note content
            Text(note.content),
            SizedBox(height: 8),
            
            // Engagement metrics
            Row(
              children: [
                Icon(Icons.favorite, size: 16),
                Text('${note.reactions.length}'),
                SizedBox(width: 16),
                Icon(Icons.flash_on, size: 16),
                Text('${note.zaps.length}'),
                SizedBox(width: 16),
                Text(note.createdAt.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

**Real-time Updates:**

```dart
// The feed automatically updates when new notes arrive
// thanks to the reactive query system

// You can also manually trigger updates
final storage = ref.read(storageNotifierProvider.notifier);

// Save a new note and it will appear in the feed
final newNote = await PartialNote('Hello, world!').signWith(signer);
await storage.save({newNote});
```

### Creating Custom Event Kinds

Extend the system with your own event kinds.

**Basic Custom Model:**

```dart
@GeneratePartialModel()
class Joke extends RegularModel<Joke> {
  Joke.fromMap(super.map, super.ref) : super.fromMap();
  
  String? get title => event.getFirstTagValue('title');
  String get punchline => event.content;
  DateTime? get publishedAt => 
      event.getFirstTagValue('published_at')?.toInt()?.toDate();
}

class PartialJoke extends RegularPartialModel<Joke> with PartialJokeMixin {
  PartialJoke({
    required String title,
    required String punchline,
    DateTime? publishedAt,
  }) {
    event.content = punchline;
    event.addTagValue('title', title);
    if (publishedAt != null) {
      event.addTagValue('published_at', publishedAt.toSeconds().toString());
    }
  }
}
```

**Registering Custom Kinds:**

```dart
// Create a custom initialization provider
final customInitializationProvider = FutureProvider((ref) async {
  await ref.read(initializationProvider(StorageConfiguration()).future);
  
  // Register your custom models
  Model.register(kind: 1055, constructor: Joke.fromMap);
  Model.register(kind: 1056, constructor: Meme.fromMap);
  
  return true;
});

// Use this provider instead of the default one
final initState = ref.watch(customInitializationProvider);
```

**Using Custom Models:**

```dart
// Create and sign a joke
final partialJoke = PartialJoke(
  title: 'The Time Traveler',
  punchline: 'I was going to tell you a joke about time travel... but you didn\'t like it.',
  publishedAt: DateTime.now(),
);

final signedJoke = await partialJoke.signWith(signer);

// Save to storage
await ref.storage.save({signedJoke});

// Query jokes
final jokesState = ref.watch(
  query<Joke>(
    authors: {signer.pubkey},
    limit: 10,
  ),
);
```

**Different Model Types:**

```dart
// Regular events (kind 1-9999)
class RegularEvent extends RegularModel<RegularEvent> {
  RegularEvent.fromMap(super.map, super.ref) : super.fromMap();
}

// Replaceable events (kind 0, 3, 10000-19999)
class ReplaceableEvent extends ReplaceableModel<ReplaceableEvent> {
  ReplaceableEvent.fromMap(super.map, super.ref) : super.fromMap();
}

// Parameterizable replaceable events (kind 30000-39999)
class ParameterizableEvent extends ParameterizableReplaceableModel<ParameterizableEvent> {
  ParameterizableEvent.fromMap(super.map, super.ref) : super.fromMap();
  
  String get identifier => event.identifier; // d-tag value
}

// Ephemeral events (kind 20000-29999)
class EphemeralEvent extends EphemeralModel<EphemeralEvent> {
  EphemeralEvent.fromMap(super.map, super.ref) : super.fromMap();
}
```

### Using the `and` Operator for Relationships

The `and` operator enables reactive relationship loading and updates.

**Basic Relationship Loading:**

```dart
// Load notes with their authors and reactions
final notesState = ref.watch(
  query<Note>(
    limit: 20,
    and: (note) => {
      note.author,      // Load author profile
      note.reactions,   // Load reactions
      note.zaps,        // Load zaps
    },
  ),
);
```

**Nested Relationships:**

```dart
// Load notes with nested relationship data
final notesState = ref.watch(
  query<Note>(
    limit: 20,
    and: (note) => {
      note.author,      // Author profile
      note.reactions,   // Reactions
      ...note.reactions.map((reaction) => reaction.author), // Reaction authors
      note.zaps,        // Zaps
      ...note.zaps.map((zap) => zap.author), // Zap authors
    },
  ),
);
```

**Conditional Relationship Loading:**

```dart
// Only load relationships for notes with content
final notesState = ref.watch(
  query<Note>(
    limit: 20,
    and: (note) => {
      if (note.content.isNotEmpty) ...[
        note.author,
        note.reactions,
      ],
    },
  ),
);
```

**Relationship Updates:**

```dart
// When a new reaction is added, all queries watching that note
// will automatically update thanks to the relationship system

final newReaction = await PartialReaction(
  reactedOn: note,
  emojiTag: ('+', 'https://example.com/plus.png'),
).signWith(signer);

await ref.storage.save({newReaction});

// The note's reactions relationship will automatically update
// and any UI watching it will rebuild
```

**Community Chat Messages:**

```dart
// Load a community with its chat messages
final communityState = ref.watch(
  query<Community>(
    ids: {communityId},
    and: (community) => {
      community.chatMessages, // Load associated chat messages
    },
  ),
);

// Access the chat messages
final community = communityState.models.first;
final messages = community.chatMessages.toList();
```

### Direct Messages & Encryption

Create encrypted direct messages using NIP-04 and NIP-44.

**Creating Encrypted Messages:**

```dart
// Create a message with automatic encryption
final dm = PartialDirectMessage(
  content: 'Hello, this is a secret message!',
  receiver: 'npub1abc123...', // Recipient's npub
  useNip44: true, // Use NIP-44 (more secure) or false for NIP-04
);

// Sign and encrypt the message
final signedDm = await dm.signWith(signer);

// Save to storage
await ref.storage.save({signedDm});
```

**Decrypting Messages:**

```dart
// Query for direct messages
final dmsState = ref.watch(
  query<DirectMessage>(
    authors: {signer.pubkey}, // Messages we sent
    tags: {'#p': {recipientPubkey}}, // Messages to specific recipient
  ),
);

// In your UI, decrypt messages asynchronously
class MessageTile extends StatelessWidget {
  final DirectMessage dm;
  
  const MessageTile({required this.dm, super.key});
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: dm.decryptContent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            title: Text('Decrypting...'),
            subtitle: Text(dm.encryptedContent),
          );
        }
        
        return ListTile(
          title: Text(snapshot.data ?? 'Failed to decrypt'),
          subtitle: Text(dm.createdAt.toString()),
        );
      },
    );
  }
}
```

**Message Threads:**

```dart
// Create a conversation view
class ConversationView extends ConsumerWidget {
  final String otherPubkey;
  
  const ConversationView({required this.otherPubkey, super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesState = ref.watch(
      query<DirectMessage>(
        authors: {signer.pubkey, otherPubkey},
        tags: {'#p': {signer.pubkey, otherPubkey}},
        limit: 100,
      ),
    );
    
    return switch (messagesState) {
      StorageLoading() => Center(child: CircularProgressIndicator()),
      StorageError() => Center(child: Text('Error loading messages')),
      StorageData() => ListView.builder(
        reverse: true,
        itemCount: messagesState.models.length,
        itemBuilder: (context, index) {
          final dm = messagesState.models[index];
          final isFromMe = dm.event.pubkey == signer.pubkey;
          
          return MessageBubble(
            message: dm,
            isFromMe: isFromMe,
          );
        },
      ),
    };
  }
}
```

**Pre-encrypted Messages:**

```dart
// For messages already encrypted by external systems
final preEncryptedDm = PartialDirectMessage.encrypted(
  encryptedContent: 'A1B2C3...', // Already encrypted content
  receiver: 'npub1abc123...',
);

final signedDm = await preEncryptedDm.signWith(signer);
```

### Working with DVMs (NIP-90)

Interact with Decentralized Virtual Machines for reputation verification and other services.

### Nostr Wallet Connect (NIP-47)

Integrate Lightning wallet functionality into your nostr applications using the Nostr Wallet Connect protocol.

**Riverpod Provider:**

The library provides a Riverpod provider for the NWC connection manager:

```dart
// Get the NWC connection manager from the provider
final nwcManager = ref.read(nwcConnectionManagerProvider);

// The provider automatically uses the active signer
// If no active signer is available, it will throw an exception
```

**Provider Details:**
- **`nwcConnectionManagerProvider`**: Provides a singleton `NwcConnectionManager` instance
- **Automatic Signer**: Uses the active signer from `Signer.activeSignerProvider`
- **Error Handling**: Throws an exception if no active signer is available
- **Lifecycle**: Automatically manages the connection manager lifecycle

**Basic NWC Setup:**

```dart
// Get the NWC connection manager from Riverpod provider
final nwcManager = ref.read(nwcConnectionManagerProvider);

// Parse a NWC URI from a wallet
final nwcUri = 'nostr+walletconnect://b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4?relay=wss%3A%2F%2Frelay.damus.io&secret=71a8c14c1407c113601079c4302dab36460f0ccd0ad506f1f2dc73b5100e4f3c&lud16=alice%40walletofsatoshi.com';

final connection = NwcConnection.fromUri(nwcUri);

// Store the connection securely (encrypted with NIP-44)
await nwcManager.storeConnection('my_wallet', connection);

// Set as active connection
await nwcManager.setActiveConnection('my_wallet');
```

**Making Wallet Requests:**

```dart
// Get the NWC connection manager
final nwcManager = ref.read(nwcConnectionManagerProvider);

// Get the active connection
final activeConnection = await nwcManager.getActiveConnection();
if (activeConnection == null) {
  print('No active NWC connection');
  return;
}

// Create a command to pay an invoice
final payCommand = PayInvoiceCommand(
  invoice: 'lnbc1000n1...',
  amount: 1000, // Optional: override amount
);

// Create and sign the request
final request = payCommand.toRequest(
  walletPubkey: activeConnection.walletPubkey,
  expiration: DateTime.now().add(Duration(minutes: 5)),
);

final signedRequest = await request.signWith(signer);

// Send the request to the wallet service
await ref.storage.publish(
  {signedRequest},
  source: RemoteSource(group: 'nwc'),
);

// Listen for responses
final responsesState = ref.watch(
  query<NwcResponse>(
    authors: {activeConnection.walletPubkey},
    kinds: {23195}, // NWC Response kind
    tags: {'#e': {signedRequest.event.id}},
  ),
);

// Handle the response
switch (responsesState) {
  case StorageData():
    if (responsesState.models.isNotEmpty) {
      final response = responsesState.models.first;
      
      // Check for errors
      final hasError = await response.hasError(signer);
      if (hasError) {
        final error = await response.getError(signer);
        print('NWC Error: ${error?.code} - ${error?.message}');
      } else {
        // Parse successful response
        final result = payCommand.parseResponse(
          await response.getResult(signer) ?? {},
        );
        print('Payment successful! Preimage: ${result.preimage}');
      }
    }
  case StorageLoading():
    print('Waiting for wallet response...');
  case StorageError():
    print('Error: ${responsesState.exception}');
}
```

**Creating Invoices:**

```dart
// Get the NWC connection manager
final nwcManager = ref.read(nwcConnectionManagerProvider);

// Create an invoice request
final makeInvoiceCommand = MakeInvoiceCommand(
  amount: 5000,
  description: 'Payment for services',
  expiry: 3600, // 1 hour
);

final request = makeInvoiceCommand.toRequest(
  walletPubkey: activeConnection.walletPubkey,
);

final signedRequest = await request.signWith(signer);
await ref.storage.publish({signedRequest}, source: RemoteSource(group: 'nwc'));

// Listen for the response
final responsesState = ref.watch(
  query<NwcResponse>(
    authors: {activeConnection.walletPubkey},
    kinds: {23195},
    tags: {'#e': {signedRequest.event.id}},
  ),
);

// Parse the invoice result
switch (responsesState) {
  case StorageData():
    if (responsesState.models.isNotEmpty) {
      final response = responsesState.models.first;
      final result = makeInvoiceCommand.parseResponse(
        await response.getResult(signer) ?? {},
      );
      print('Invoice created: ${result.invoice}');
      print('Payment hash: ${result.paymentHash}');
    }
  // ... handle other states
}
```

**Getting Wallet Balance:**

```dart
// Get the NWC connection manager
final nwcManager = ref.read(nwcConnectionManagerProvider);

final balanceCommand = GetBalanceCommand();
final request = balanceCommand.toRequest(
  walletPubkey: activeConnection.walletPubkey,
);

final signedRequest = await request.signWith(signer);
await ref.storage.publish({signedRequest}, source: RemoteSource(group: 'nwc'));

// Listen for balance response
final responsesState = ref.watch(
  query<NwcResponse>(
    authors: {activeConnection.walletPubkey},
    kinds: {23195},
    tags: {'#e': {signedRequest.event.id}},
  ),
);

switch (responsesState) {
  case StorageData():
    if (responsesState.models.isNotEmpty) {
      final response = responsesState.models.first;
      final result = balanceCommand.parseResponse(
        await response.getResult(signer) ?? {},
      );
      print('Wallet balance: ${result.balance} sats');
    }
  // ... handle other states
}
```

**Listening for Wallet Notifications:**

```dart
// Watch for wallet notifications
final notificationsState = ref.watch(
  query<NwcNotification>(
    authors: {activeConnection.walletPubkey},
    kinds: {23196}, // NWC Notification kind
  ),
);

switch (notificationsState) {
  case StorageData():
    for (final notification in notificationsState.models) {
      final type = await notification.getNotificationType(signer);
      
      switch (type) {
        case 'payment_received':
          final data = await notification.getNotification(signer);
          print('Payment received: ${data?['amount']} sats');
          break;
        case 'payment_sent':
          final data = await notification.getNotification(signer);
          print('Payment sent: ${data?['amount']} sats');
          break;
      }
    }
  // ... handle other states
}
```

**Managing Multiple Connections:**

```dart
// Get the NWC connection manager
final nwcManager = ref.read(nwcConnectionManagerProvider);

// Store multiple wallet connections
await nwcManager.storeConnection('wallet1', connection1);
await nwcManager.storeConnection('wallet2', connection2);

// Get all stored connections
final allConnections = await nwcManager.getAllConnections();
print('Stored connections: ${allConnections.keys}');

// Switch between connections
await nwcManager.setActiveConnection('wallet2');

// Remove a connection
await nwcManager.removeConnection('wallet1');
```

**Wallet Service Discovery:**

```dart
// Query for wallet service info
final walletInfoState = ref.watch(
  query<NwcInfo>(
    authors: {walletPubkey},
    kinds: {13194}, // NWC Info kind
  ),
);

switch (walletInfoState) {
  case StorageData():
    if (walletInfoState.models.isNotEmpty) {
      final info = walletInfoState.models.first;
      
      // Check supported methods
      if (info.supportsMethod('pay_invoice')) {
        print('Wallet supports invoice payments');
      }
      
      if (info.supportsMethod('make_invoice')) {
        print('Wallet can create invoices');
      }
      
      // Check supported notifications
      if (info.supportsNotification('payment_received')) {
        print('Wallet sends payment received notifications');
      }
    }
  // ... handle other states
}
```

**Error Handling:**

```dart
// Handle common NWC errors
try {
  final result = await sendNwcRequest(command);
  // Handle success
} catch (e) {
  if (e is NwcError) {
    switch (e.code) {
      case NwcError.insufficientBalance:
        print('Insufficient balance in wallet');
        break;
      case NwcError.rateLimited:
        print('Rate limited - try again later');
        break;
      case NwcError.unauthorized:
        print('Unauthorized - check connection permissions');
        break;
      default:
        print('NWC error: ${e.message}');
    }
  }
}
```

**Connection Limits and Permissions:**

```dart
// Create connection with limits
final limitedConnection = NwcConnection(
  walletPubkey: walletPubkey,
  secret: secret,
  relay: relay,
  limits: NwcConnectionLimits(
    maxAmount: 10000, // 10k sats max per period
    budgetRenewal: NwcBudgetRenewal.daily,
    allowedMethods: {'pay_invoice', 'get_balance'},
  ),
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(Duration(days: 30)),
);

// Check if connection has expired
if (limitedConnection.isExpired) {
  print('Connection has expired');
}

// Check budget limits
if (limitedConnection.limits?.maxAmount != null) {
  print('Max amount per ${limitedConnection.limits!.budgetRenewal}: ${limitedConnection.limits!.maxAmount} sats');
}
```

**Secure Storage:**

The NWC connection manager uses NIP-44 encryption to securely store sensitive connection data:

```dart
// Get the NWC connection manager
final nwcManager = ref.read(nwcConnectionManagerProvider);

// Store a standalone secret
await nwcManager.storeSecret('api_key', 'secret_api_key_value');

// Retrieve the secret
final apiKey = await nwcManager.getSecret('api_key');

// Remove the secret
await nwcManager.removeSecret('api_key');
```

**Complete NWC Integration Example:**

```dart
class NwcWalletService {
  final NwcConnectionManager _manager;
  final StorageNotifier _storage;
  final Signer _signer;

  NwcWalletService(Ref ref, {Signer? signer})
    : _manager = signer != null 
        ? NwcConnectionManager(ref, signer: signer)
        : ref.read(nwcConnectionManagerProvider),
      _storage = ref.read(storageNotifierProvider.notifier),
      _signer = signer ?? ref.read(Signer.activeSignerProvider)!;

  /// Connect to a wallet using NWC URI
  Future<void> connectWallet(String nwcUri, String connectionId) async {
    final connection = NwcConnection.fromUri(nwcUri);
    await _manager.storeConnection(connectionId, connection);
    await _manager.setActiveConnection(connectionId);
  }

  /// Pay an invoice
  Future<PayInvoiceResult?> payInvoice(String invoice, {int? amount}) async {
    final connection = await _manager.getActiveConnection();
    if (connection == null) throw Exception('No active NWC connection');

    final command = PayInvoiceCommand(invoice: invoice, amount: amount);
    final request = command.toRequest(walletPubkey: connection.walletPubkey);
    final signedRequest = await request.signWith(_signer);

    await _storage.publish({signedRequest}, source: RemoteSource(group: 'nwc'));

    // Wait for response (in real app, use proper async handling)
    await Future.delayed(Duration(seconds: 2));

    final responses = await _storage.query(
      RequestFilter<NwcResponse>(
        authors: {connection.walletPubkey},
        kinds: {23195},
        tags: {'#e': {signedRequest.event.id}},
      ).toRequest(),
    );

    if (responses.isNotEmpty) {
      final response = responses.first;
      if (await response.hasError(_signer)) {
        final error = await response.getError(_signer);
        throw Exception('NWC Error: ${error?.code} - ${error?.message}');
      }
      
      final result = await response.getResult(_signer);
      return result != null ? command.parseResponse(result) : null;
    }

    return null;
  }

  /// Get wallet balance
  Future<int?> getBalance() async {
    final connection = await _manager.getActiveConnection();
    if (connection == null) throw Exception('No active NWC connection');

    final command = GetBalanceCommand();
    final request = command.toRequest(walletPubkey: connection.walletPubkey);
    final signedRequest = await request.signWith(_signer);

    await _storage.publish({signedRequest}, source: RemoteSource(group: 'nwc'));

    // Wait for response
    await Future.delayed(Duration(seconds: 2));

    final responses = await _storage.query(
      RequestFilter<NwcResponse>(
        authors: {connection.walletPubkey},
        kinds: {23195},
        tags: {'#e': {signedRequest.event.id}},
      ).toRequest(),
    );

    if (responses.isNotEmpty) {
      final response = responses.first;
      final result = await response.getResult(_signer);
      return result != null ? command.parseResponse(result).balance : null;
    }

    return null;
  }

  /// Create an invoice
  Future<MakeInvoiceResult?> createInvoice({
    required int amount,
    String? description,
    int? expiry,
  }) async {
    final connection = await _manager.getActiveConnection();
    if (connection == null) throw Exception('No active NWC connection');

    final command = MakeInvoiceCommand(
      amount: amount,
      description: description,
      expiry: expiry,
    );
    final request = command.toRequest(walletPubkey: connection.walletPubkey);
    final signedRequest = await request.signWith(_signer);

    await _storage.publish({signedRequest}, source: RemoteSource(group: 'nwc'));

    // Wait for response
    await Future.delayed(Duration(seconds: 2));

    final responses = await _storage.query(
      RequestFilter<NwcResponse>(
        authors: {connection.walletPubkey},
        kinds: {23195},
        tags: {'#e': {signedRequest.event.id}},
      ).toRequest(),
    );

    if (responses.isNotEmpty) {
      final response = responses.first;
      final result = await response.getResult(_signer);
      return result != null ? command.parseResponse(result) : null;
    }

    return null;
  }

  /// Listen for payment notifications
  Stream<NwcNotification> get paymentNotifications {
    final connection = _manager.getActiveConnection();
    if (connection == null) return Stream.empty();

    return _storage.query(
      RequestFilter<NwcNotification>(
        authors: {connection.walletPubkey},
        kinds: {23196},
      ).toRequest(),
    ).asStream().expand((notifications) => notifications);
  }
}
```

**Creating DVM Requests:**

```dart
// Create a reputation verification request
final request = PartialVerifyReputationRequest(
  source: 'npub1source123...',
  target: 'npub1target456...',
);

final signedRequest = await request.signWith(signer);

// Run the DVM request
final response = await signedRequest.run('default'); // relay group

if (response != null) {
  if (response is VerifyReputationResponse) {
    print('Reputation verified: ${response.pubkeys}');
  } else if (response is DVMError) {
    print('DVM error: ${response.status}');
  }
}
```

**Custom DVM Models:**

```dart
// Create your own DVM request model
class CustomDVMRequest extends RegularModel<CustomDVMRequest> {
  CustomDVMRequest.fromMap(super.map, super.ref) : super.fromMap();
  
  Future<Model<dynamic>?> run(String relayGroup) async {
    final source = RemoteSource(group: relayGroup);
    
    // Publish the request
    await storage.publish({this}, source: source);
    
    // Wait for responses
    final responses = await storage.query(
      RequestFilter(
        kinds: {7001}, // Your response kind
        tags: {'#e': {event.id}}, // Reference to this request
      ).toRequest(),
      source: source,
    );
    
    return responses.firstOrNull;
  }
}

class PartialCustomDVMRequest extends RegularPartialModel<CustomDVMRequest> {
  PartialCustomDVMRequest({
    required String parameter1,
    required String parameter2,
  }) {
    event.addTag('param', ['param1', parameter1]);
    event.addTag('param', ['param2', parameter2]);
  }
}
```

**DVM Response Handling:**

```dart
// Handle different types of DVM responses
class DVMResponseHandler {
  static void handleResponse(Model<dynamic> response) {
    switch (response) {
      case VerifyReputationResponse():
        print('Reputation verified: ${response.pubkeys}');
        break;
      case DVMError():
        print('DVM error: ${response.status}');
        break;
      case CustomDVMResponse():
        print('Custom response: ${response.data}');
        break;
      default:
        print('Unknown response type');
    }
  }
}

// Use in your app
final response = await dvmRequest.run('default');
if (response != null) {
  DVMResponseHandler.handleResponse(response);
}
```

**DVM Error Handling:**

```dart
// Robust DVM interaction with error handling
Future<Model<dynamic>?> runDVMWithRetry(
  Model<dynamic> request,
  String relayGroup, {
  int maxRetries = 3,
  Duration delay = Duration(seconds: 5),
}) async {
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      final response = await request.run(relayGroup);
      
      if (response is DVMError) {
        print('DVM error on attempt $attempt: ${response.status}');
        if (attempt < maxRetries) {
          await Future.delayed(delay);
          continue;
        }
      }
      
      return response;
    } catch (e) {
      print('DVM request failed on attempt $attempt: $e');
      if (attempt < maxRetries) {
        await Future.delayed(delay);
        continue;
      }
      rethrow;
    }
  }
  
  return null;
}
```

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

### Model Types

Available built-in models and their relationships.

**Core Models:**
- `Profile` (kind 0) - User profiles with metadata
- `Note` (kind 1) - Text posts with reply threading
- `ContactList` (kind 3) - Following/followers
- `DirectMessage` (kind 4) - Encrypted private messages
- `Repost` (kind 6) - Reposts of other notes (NIP-18)
- `Reaction` (kind 7) - Emoji reactions to events
- `ChatMessage` (kind 9) - Public chat messages

**Content Models:**
- `Article` (kind 30023) - Long-form articles
- `App` (kind 32267) - App metadata and listings
- `Release` (kind 30063) - Software releases
- `FileMetadata` (kind 1063) - File information with release relationship
- `SoftwareAsset` (kind 3063) - Software binaries

**Social Models:**
- `Community` (kind 10222) - Community definitions with chatMessages relationship
- `TargetedPublication` (kind 30222) - Targeted content
- `Comment` (kind 1111) - Comments on content

**Monetization:**
- `ZapRequest` (kind 9734) - Lightning payment requests
- `Zap` (kind 9735) - Lightning payments

**DVM Models:**
- `VerifyReputationRequest` (kind 5312) - Reputation verification
- `VerifyReputationResponse` (kind 6312) - Reputation results
- `DVMError` (kind 7000) - DVM error responses

**NWC (Nostr Wallet Connect) Models:**
- `NwcInfo` (kind 13194) - Wallet service capabilities and supported methods
- `NwcRequest` (kind 23194) - Encrypted requests from client to wallet service
- `NwcResponse` (kind 23195) - Encrypted responses from wallet service to client
- `NwcNotification` (kind 23196) - Encrypted notifications from wallet service to client
- `NwcConnection` - Connection management with secure storage
- `NwcConnectionManager` - Secure connection management with NIP-44 encryption
- `NwcCommand<T>` - Type-safe command classes for wallet operations

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
ref.listen(storageNotifierProvider, (previous, next) {
  if (next is StorageError) {
    print('Storage error: ${next.exception}');
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
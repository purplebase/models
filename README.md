# 𝌭 nostr-models

A simple and efficient local-first nostr framework. Written in Dart.

It provides:
 - Domain-specific models that wrap common nostr event kinds (with relationships between them)
 - A local-first model storage and relay interface, leveraging reactive Riverpod providers

```dart
// An offline-ready feed with reactions/zaps in a few lines of code
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

This library is meant to be a common interface for Dart/Flutter nostr projects, diverse implementations are encouraged.

Current implementations:
  - Dummy: In-memory storage and relay fetch simulation, for testing and prototyping (default, included)
  - [Purplebase](https://github.com/purplebase/purplebase): SQLite-powered storage and an efficient relay pool

## Table of Contents 📜

- [Features ✨](#features-)
- [Installation 🛠️](#installation-️)
- [Quickstart 🚀](#quickstart-)
- [Advanced Usage 🧠](#advanced-usage-)
  - [Querying with Relationships](#querying-with-relationships)
  - [Adding Custom Models](#adding-custom-models)
  - [Generating Dummy Data for Testing](#generating-dummy-data-for-testing)
- [Recipes 🍳](#recipes-)
- [Design Goals 🎯](#design-goals-)
- [Design Notes 📝](#design-notes-)
- [Contributing 🙏](#contributing-)
- [License 📄](#license-)

## Features ✨

 - **Domain models**: Use natural domain language to interact with nostr concepts instead of NIP-jargon, typed classes for common nostr event kinds available (or bring your own) (e.g. `author.nip05`, `author.nameOrNpub`, everything is parsed, cached and ready to use)
 - **Relationships**: Smoothly navigate local storage with model relationships (`note.reactions.first.author.zaps`) and query relays (`and: (note) => {note.reactions, note.zaps}`)
 - **Watchable queries**: Reactive querying interface with a familiar nostr request filter API, loads from local storage and keeps updating with remote relay data
 - **Signer API**: Construct new nostr events and sign them using Amber (Android) and other NIP-55 signers available via external packages, or when testing the built-in dummy signer
 - **Reactive signed-in profile provider**: Keep track of the currently signed in pubkeys and the active user in your application with `signedInProfileProvider`
 - **Publishing**: Publish events to specified relays
 - **Dummy implementation**: Plug-and-play implementation for testing/prototyping, easily generate dummy profiles, notes, contact lists, etc.
 - **Eviction strategy**: Specify `keepMaxEvents` to automatically remove older events (FIFO)
 - **Raw events**: Access underlying nostr event data (`event` property on all models)
 - and much more

## Installation 🛠️

Add the dependency to your `pubspec.yaml`:

(Use git until we publish to pub.dev)

```yaml
dependencies:
  models:
    git:
      url: https://github.com/purplebase/models
      ref: 0.1.0
```

Then run `dart pub get` or `flutter pub get`.

## Quickstart 🚀

Here is a minimal Flutter/Riverpod app that generates and shows a nostr feed.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';

void main() => runApp(ProviderScope(child: MaterialApp(home: ProfileScreen())));

class ProfileScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(initializationProvider(StorageConfiguration()))) {
      AsyncLoading() => Center(child: CircularProgressIndicator()),
      AsyncError() => Center(child: Text('Error initializing')),
      _ => Scaffold(
        body: Consumer(
          builder: (context, ref, _) {
            final signedInProfile = ref.watch(Profile.signedInProfileProvider);
            if (signedInProfile == null) {
              return Center(
                child: Text('Tap button to generate feed and sign in'),
              );
            }
            final state = ref.watch(
              query<Note>(
                limit: 10, // total pre-EOSE
                queryLimit: 100, // total including streaming
                authors: signedInProfile.contactList.value!.followingPubkeys,
                and: (note) => {note.author, note.reactions, note.zaps},
              ),
            );
            return ListView(
              children: [
                for (final note in state.models)
                  Card(
                    child: ListTile(
                      title: Text(note.content),
                      subtitle: Text(
                        '${note.author.value!.name}\n${note.createdAt.toIso8601String()}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite, size: 16),
                          Text('${note.reactions.length}'),
                          SizedBox(width: 8),
                          Icon(Icons.flash_on, size: 16),
                          Text(
                            '${note.zaps.toList().fold(0, (acc, e) => acc += e.amount)}',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.login),
          onPressed: () {
            final storage =
                ref.read(storageNotifierProvider.notifier)
                    as DummyStorageNotifier;
            storage.generateFeed();
          },
        ),
      ),
    };
  }
}
```

## Advanced Usage 🧠

### Querying with Relationships

Fetch notes by an author and automatically include their associated reactions (Kind 7 events):

```dart
final state = container.watch(
  query<Note>(
    authors: {'pubkey123'},
    // Also watch for related models (e.g., reactions)
    and: (note) => {note.reactions},
    remote: true, // false if it should not hit relays
  )
);

state.when(
  data: (storageData) {
    for (final note in storageData.models) {
      print('Note: ${note.content}');
      // Access related reactions directly
      for (final reaction in note.reactions) {
        print('  Reaction: ${reaction.content}');
      }
    }
  },
  // ... handle loading and error states
);
```

The `and` parameter ensures the watcher updates not only when matching `Note`s change but also when related `Reaction`s linked to those notes change in storage.

### Adding Custom Models

Define a model for a custom event kind (e.g., Kind 1055 for Jokes).

1.  **Define the Model Class:** Extend `RegularModel`, `ReplaceableModel`, etc.

    ```dart
    import 'package:nostr_models/nostr_models.dart';

    /// Signed, immutable Joke model (Kind 1055)
    class Joke extends RegularModel<Joke> {
      Joke.fromMap(super.map, super.ref) : super.fromMap();

      String? get title => event.getFirstTagValue('title');
      DateTime? get publishedAt =>
          event.getFirstTagValue('published_at')?.toInt()?.toDate();

      // Register this model type
      static void register() {
        Model.register(kind: 1055, constructor: Joke.fromMap);
      }
    }
    ```

2.  **Define the Partial Model Class:** For creating and signing new events.

    ```dart
    /// Unsigned, mutable partial Joke for creation
    class PartialJoke extends RegularPartialModel<Joke> {
      PartialJoke(String title, String content, {DateTime? publishedAt}) {
        event.kind = 1055; // Set the correct kind
        event.content = content;
        event.addTagValue('title', title);
        if (publishedAt != null) {
          event.addTagValue('published_at', publishedAt.toSeconds().toString());
        }
      }
    }
    ```

3.  **Register the Model:** Call the `register` method during your app initialization.

    ```dart
    void main() {
      Joke.register(); // Register the custom model
      // ... rest of your app initialization
      runApp(ProviderScope(child: MyApp()));
    }
    ```

4.  **Use the Custom Model:**

    ```dart
    // Create and sign a joke
    final partialJoke = PartialJoke(
      'The Time Traveler',
      'I was going to tell you a joke about time travel... but you didn't like it.',
      publishedAt: DateTime.parse('2025-02-02'),
    );
    final signedJoke = await partialJoke.signWith(signer); // Use your signer

    // Publish it
    await storage.publish(signedJoke);

    // Query for jokes
    final jokesStream = container.watch(query<Joke>(kinds: {1055}));
    jokesStream.when(
      data: (storageData) {
        for (final joke in storageData.models) {
          print('Joke Title: ${joke.title}, Content: ${joke.content}');
        }
      },
      // ... handle loading/error
    );
    ```

### Generating Dummy Data for Testing

Use the `DummyStorageNotifier` to populate storage with test data.

```dart
import 'dart:math';
import 'package:nostr_models/nostr_models.dart';

// Ensure you are using the DummyStorage implementation
final storageNotifier = container.read(storageNotifierProvider.notifier);
if (storageNotifier is! DummyStorageNotifier) {
  throw Exception('Expected DummyStorageNotifier for data generation');
}
final storage = storageNotifier as DummyStorageNotifier;
final r = Random();

// Generate a main profile and some followers
final profile = storage.generateProfile();
final follows = List.generate(min(15, r.nextInt(50)),
    (i) => storage.generateProfile());

// Generate a contact list for the main profile
final contactList = storage.generateModel(
  kind: 3,
  pubkey: profile.pubkey,
  pTags: follows.map((e) => e.event.pubkey).toList(),
)!;

// Generate notes, likes, and zaps from followers
final otherModels = <Model>{};
List.generate(r.nextInt(200), (i) {
  final note = storage.generateModel(
    kind: 1,
    pubkey: follows[r.nextInt(follows.length)].pubkey,
    createdAt: DateTime.now().subtract(Duration(minutes: r.nextInt(300))),
  )!;
  otherModels.add(note);

  // Generate related reactions (likes)
  final likes = List.generate(r.nextInt(10), (i) {
    return storage.generateModel(kind: 7, parentId: note.id)!;
  });
  // Generate related zaps
  final zaps = List.generate(r.nextInt(3), (i) {
    return storage.generateModel(kind: 9735, parentId: note.id)!;
  });
  otherModels.addAll(likes);
  otherModels.addAll(zaps);
});

// Save all generated models to the dummy storage
await storage.save({profile, ...follows, contactList, ...otherModels});

print('Dummy data generated and saved.');
```

## Recipes 🍳

This section contains more complete, practical examples using Flutter.

### Building a Basic Feed

This example shows a minimal Flutter app using Riverpod to:
- Simulate user sign-in with a `DummySigner`.
- Fetch recent global notes (Kind 1).
- Display the notes in a list.
- Allow the "signed-in" user to publish new notes.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_models/nostr_models.dart';

// --- Providers ---

// 1. Signer Provider (Simulates logged-in user)
// Replace DummySigner with your actual signer implementation
final signedInUserProvider = StateProvider<Signer?>((ref) => DummySigner());

// 2. Initialization Provider (Ensures setup is complete)
final initializationProvider = FutureProvider<void>((ref) async {
  // Add any async initialization here (e.g., loading keys, registering models)
  // Model.register(...); // If using custom models
  await Future.delayed(Duration.zero); // Simulate potential async work
});

// 3. Feed Provider (Queries recent notes)
final feedProvider = StreamProvider<StorageData<Note>>((ref) {
  // Important: Ensure initialization is complete before querying
  ref.watch(initializationProvider);

  print('Watching feed query...');
  return ref.watch(query<Note>(
    kinds: {1}, // Fetch only notes
    limit: 50, // Limit the number of notes
    // Add other filters like authors (following) or since/until as needed
  ));
});

// --- Main App ---

void main() {
  runApp(
    // 1. Add ProviderScope at the top
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nostr Feed Example',
      home: FeedScreen(),
    );
  }
}

// --- Feed Screen Widget ---

class FeedScreen extends ConsumerWidget {
  final _textController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ensure initialization is complete before building the UI
    final init = ref.watch(initializationProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Simple Nostr Feed')),
      body: init.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Initialization Error: $err')),
        data: (_) => Column(
          children: [
            // --- Post Input Area ---
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(hintText: 'What\'s happening?'),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: () async {
                      final signer = ref.read(signedInUserProvider);
                      final storage = ref.read(storageNotifierProvider.notifier);
                      final content = _textController.text;

                      if (signer != null && content.isNotEmpty) {
                        try {
                          final partialNote = PartialNote(content);
                          final signedNote = await partialNote.signWith(signer);
                          print('Publishing note: ${signedNote.id}');
                          await storage.publish(signedNote); // Publish to relays
                          _textController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Note published!')),
                          );
                        } catch (e) {
                          print('Error publishing note: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            Divider(),
            // --- Feed Area ---
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final feedAsyncValue = ref.watch(feedProvider);
                  return feedAsyncValue.when(
                    data: (storageData) {
                      final notes = storageData.models.toList();
                      // Sort notes by creation date, newest first
                      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                      if (notes.isEmpty) {
                        return Center(child: Text('Feed is empty.'));
                      }

                      return ListView.builder(
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return ListTile(
                            title: Text(note.content),
                            subtitle: Text(
                                'By: ${note.pubkey.substring(0, 8)}... at ${note.createdAt.toLocal()}'),
                          );
                        },
                      );
                    },
                    loading: () => Center(child: CircularProgressIndicator()),
                    error: (err, stack) {
                      print('Feed Error: $err\n$stack');
                      return Center(child: Text('Error loading feed: $err')),
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Watching Specific Events with `RequestFilter`

_(Coming Soon: Example demonstrating how to create a specific `RequestFilter` and use `ref.watch(query(...))` to reactively display matching events.)_

### Interacting with DVMs (NIP-90)

_(Coming Soon: Example showcasing how to create DVM requests and process results using the library.)_

## Design Goals 🎯

 - Leverage Dart for maximum type safety and intuitive APIs.
 - Abstract Nostr NIP details into domain-specific language.
 - Provide access to lower-level interfaces (`Event`, `Tag`, etc.) when needed.
 - Enable easy extension with custom event kinds and models.
 - Offer a reactive, local-first approach to data handling.

## Design Notes 📝

- Built on Riverpod providers (`storageNotifierProvider`, `query`, etc.).
- Aims for high test coverage.
- The `Storage` interface acts similarly to a relay but is optimized for local use (e.g., storing replaceable event IDs, potentially storing decrypted data, managing eviction).
- Queries (`ref.watch(query<...>(...))`) primarily interact with the local `Storage`.
- By default, queries also trigger requests to configured remote relays. Results are saved to `Storage`, automatically updating watchers.
- The system tracks query timestamps (`since`) to optimize subsequent fetches from relays.
- Relay pools can be configured (e.g., `storage.configure('my-pool', {'wss://relay.example.com'})`) and used for publishing (`storage.publish(event, to: {'my-pool'})`).

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
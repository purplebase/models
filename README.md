# nostr-models 👯

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

## Table of Contents 📜

- [Features ✨](#features-)
- [Installation 🛠️](#installation-️)
- [Quickstart 🚀](#quickstart-)
- [Advanced Usage 🧠](#advanced-usage-)
  - [Querying with Relationships](#querying-with-relationships)
  - [Adding Custom Models](#adding-custom-models)
  - [Generating Dummy Data for Testing](#generating-dummy-data-for-testing)
- [Recipes 🍳](#recipes-)
- [Design Notes 📝](#design-notes-)
- [Contributing 🙏](#contributing-)
- [License 📄](#license-)

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

### Adding Custom Models

Define a model for a custom event kind (e.g. kind 1055 for jokes).

```dart
import 'package:nostr_models/nostr_models.dart';

/// Signed, immutable Joke model
class Joke extends RegularModel<Joke> {
  Joke.fromMap(super.map, super.ref) : super.fromMap();

  String? get title => event.getFirstTagValue('title');
  DateTime? get publishedAt =>
      event.getFirstTagValue('published_at')?.toInt()?.toDate();
}

/// Unsigned, mutable partial Joke for creation
class PartialJoke extends RegularPartialModel<Joke> {
  PartialJoke(String title, String content, {DateTime? publishedAt}) {
    event.content = content;
    event.addTagValue('title', title);
    if (publishedAt != null) {
      event.addTagValue('published_at', publishedAt.toSeconds().toString());
    }
  }
}
```

Then, register the model. It is recommended to do this in a `customInitializationProvider`. Now call this initializer in your app instead of the default.

```dart
final customInitializationProvider = FutureProvider((ref) async {
  await ref.read(initializationProvider(StorageConfiguration(...)).future);
  Model.register(kind: 1055, constructor: Joke.fromMap);
});
```

Use it:

```dart
// Create and sign a joke
final partialJoke = PartialJoke(
  'The Time Traveler',
  'I was going to tell you a joke about time travel... but you didn\'t like it.',
  publishedAt: DateTime.parse('2025-02-02'),
);
final signedJoke = await partialJoke.signWith(signer); // Use your signer

// Publish it
await storage.save(signedJoke, publish: true);
```

### Generating Dummy Data for Testing

Use the `DummyStorageNotifier` to populate storage with test data. This can be done in a custom initializer (like shown above), or on a button callback like in the Quickstart sample app.

```dart
import 'dart:math';
import 'package:nostr_models/nostr_models.dart';

final storage = container.read(storageNotifierProvider.notifier) as DummyStorageNotifier;

// NOTE: a handy method for generating a whole feed is available
// It generates a fake profile, follows, a contact list, and a bunch of notes, reactions and zaps
storage.generateFeed(pubkey);

// Or manually...

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

// Save all generated models to the dummy storage
await storage.save({profile, ...follows, contactList});
```

## Recipes 🍳

This section contains more complete, practical examples using Flutter.

### Watching Specific Events with `RequestFilter`

_(Coming Soon: Example demonstrating how to create a specific `RequestFilter` and use `ref.watch(query(...))` to reactively display matching events.)_

### Interacting with DVMs (NIP-90)

_(Coming Soon: Example showcasing how to create DVM requests and process results using the library.)_

## Design Notes 📝

- Built on Riverpod providers (`storageNotifierProvider`, `query`, etc.).
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
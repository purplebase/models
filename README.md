# nostr-models

Nostr model and local-first reactive relay interface in Dart.

It includes a dummy data implementation that can be used in tests and prototypes and can be overridden in one line of code.

[Purplebase](https://github.com/purplebase/purplebase) is an implementation backed by SQLite and actual relays.

## Adding your own models

Add a joke model of kind 1055. Extend from `RegularModel` or `ReplaceableModel` etc as appropriate. Models are classes meant to wrap nostr event data and expose it as domain language, properly typed.

The lower level object holding raw nostr event data is accessible at `event` in every model.

```dart
/// This is a signed, immutable Joke model
class Joke extends RegularModel<Joke> {
  // Call super to deserialize from a map
  Joke.fromMap(super.map, super.ref) : super.fromMap();

  // Getter to the title tag
  String? get title => event.getFirstTagValue('title');
  // Getter to published_at tag, converting to DateTime
  DateTime? get publishedAt =>
      event.getFirstTagValue('published_at')?.toInt()?.toDate();
}

/// This is a PartialJoke, unsigned and mutable model
/// on which .signWith() is called to produce a Joke model
class PartialJoke extends RegularPartialModel<Joke> {
  PartialJoke(String title, String content, {DateTime? publishedAt}) {
    event.addTagValue('title', title);
    event.content = content;
    event.addTagValue('published_at', publishedAt?.toSeconds().toString());
  }
}
```

And in your initializer call:

```dart
Model.register(kind: 1055, constructor: Joke.fromMap);
```

That's it. You can now use jokes in your app:

```dart
final joke = PartialJoke('The Time Traveler',
        'I was going to tell you a joke about time travel... but you didn\'t like it.',
        publishedAt: DateTime.parse('2025-02-02'))
    .dummySign();
print(jsonEncode(joke.toMap()));
// {id: c717b625dfd623f660847ec26c14de33b5cccb2f4cf3bad41297546dd7230941, content: I was going to tell you a joke about time travel... but you didn't like it., created_at: 1744851226, pubkey: f907e6c86c02efe9e26c2d028c6d5112e19308e3cc54a3ff016ac0e9e1af0ff1, kind: 1055, tags: [[title, The Time Traveler], [published_at, 1738465200]], sig: null}

final joke2 = Joke.fromMap({'id': 'c717b625dfd623f660847ec26c14de33b5cccb2f4cf3bad41297546dd7230941', 'content': 'I was going to tell you a joke about time travel... but you didn\'t like it.', 'created_at': 1744851226, 'pubkey': 'f907e6c86c02efe9e26c2d028c6d5112e19308e3cc54a3ff016ac0e9e1af0ff1', 'kind': 1055, 'tags': [['title', 'The Time Traveler'], ['published_at', 1738465200]], 'sig': null}, ref);
```

## Generate dummy models

This can go in the initializer, for example. Then query normally.

```dart
final r = Random();
final storage = ref.read(storageNotifierProvider.notifier) as DummyStorageNotifier;

final profile = storage.generateProfile(franzap);
final follows = List.generate(min(15, r.nextInt(50)),
    (i) => storage.generateProfile());

final contactList = storage.generateModel(
  kind: 3,
  pubkey: profile.pubkey,
  pTags: follows.map((e) => e.event.pubkey).toList(),
)!;

// notes, likes, zaps
final other = <Model>{};
List.generate(r.nextInt(500), (i) {
  final note = storage.generateModel(
    kind: 1,
    pubkey: follows[r.nextInt(follows.length)].pubkey,
    createdAt: DateTime.now()
        .subtract(Duration(minutes: r.nextInt(300))),
  )!;
  other.add(note);
  final likes = List.generate(r.nextInt(50), (i) {
    return storage.generateModel(
        kind: 7, parentId: note.id)!;
  });
  final zaps = List.generate(r.nextInt(10), (i) {
    return storage.generateModel(
        kind: 9735,
        parentId: note.id)!;
  });
  other.addAll(likes);
  other.addAll(zaps);
});

await storage.save({profile, ...follows, contactList, ...other});
```

## Design goals

 - Leverage the Dart language to provide maximum type safety and beautiful interfaces that make sense
 - Allow consuming nostr events using domain language and not NIP technicality
 - Allow access to lower level interfaces
 - Allow defining new classes in an intuitive way

## Design notes

Built on Riverpod providers and StateNotifier notifiers.

Aims to have as much test coverage as possible.

Storage with a nostr relay API is at the core of this approach. Querying is done via a family provider where the argument is a nostr filter.

Example:

```dart
ref.watch(
  query<Note>(
    authors: {'a1b2c3'},
    since: DateTime.now().subtract(Duration(seconds: 5)
  )
);
```

Every single model coming through this watcher comes from local storage and never from a relay directly. 

Also, every call by default hits nostr relays (it can be disabled) and saves the returned models to local storage therefore immediately showing up via the watcher - if its filter matches.

The system is aware of previously loaded data so it will add different `since` filters to relay queries appropriately.

To prevent local storage bloat, an eviction policy callback will be made available to clients.

The modelling layer intends to abstract away NIP jargon and be as domain language as possible. It will include a powerful relationship API, such that the following can be performed:

```dart
final note = await storage.query<Note>(authors: {'a'});
final Note reply = await PartialNote('this is cool', replyTo: note).signWith(signer);
print(note.replies.toList());
// And maybe:
await storage.publish(reply, to: {'big-relays'});

// Generic models for multiple kinds
final models = await storage.queryKinds(kinds: {7, 9735}, authors: {'a'});

// The initial note could of course be retrieved like:
final note = signedInProfile.notes.first;
```

And then:

```dart
final state = ref.watch(query<Note>(authors: {'a1b2c3'}, and: (note) => {note.replies}));

// ...
children: [
 if (state case StorageData(:final models))
  for (final note in models)
    for (final reply in note.replies)
      ListTile(
        title: Text('Note ${note.content} has reply: ${reply}'),
      )
]
```

What is important to note here is that the watcher will repaint the widget when any model in storage matches the regular filter. But a reply does not match the regular filter, as it is not a kind 1. That is where the `and` argument comes in, allowing now to repaint upon replies, but not any reply!, only those in a relationship with any matching kind 1 of the regular filter.

Lastly, watching replaceable model will also be a thing:

```dart
final Profile signedInProfile = ref.watch(signedInProfileProvider);
final state = ref.watch(query<Profile>(signedInProfile, and: (note) => {note.following}));
```

Relays can be configured in pools, e.g. `storage.configure('big-relays', {'wss://relay.damus.io', 'wss://relay.primal.net'})` and then addressed by label throughout the application; when no relay pools are supplied it is inferred that the outbox model must be utilized.

### Storage vs relay

A storage is very close to a relay but has some key differences, it:

 - Stores replaceable event IDs as the main ID for querying
 - Discards event signatures after validation, so not meant for rebroadcasting
 - Tracks origin relays for events, as well as connection timestamps for subsequent time-based querying
 - Has more efficient interfaces for mass deleting data
 - Can store decrypted DMs or cashu tokens, cache profile images, etc

## TODO

 - [x] Relay, request and other basic interfaces
 - [x] Storage API and in-memory implementation
 - [x] Popular nostr models, at least those used in Zaplab
 - [x] Model relationships
 - [x] Buffered relay pool, with configurable duration
 - [x] Watchable relationships
 - [x] Allow typed queries `ref.watch(query<Note>(authors: {'a'}))` - specialized case, does not allow `kinds` in filter
 - [x] Remote relay configuration
 - [x] Relay metadata in response
 - [x] Cache relationship req results, make relationships check it before hitting sync
 - [x] Publish events
 - [x] Merge reqs for both local storage and relays
 - [x] Register types externally (+docs)
 - [x] Event metadata
 - [x] Eviction API to manage db size
 - [x] Add more models based on NIPs, hook up nostr MCP and ask agent
 - [x] `signedInProfilesProvider`, with ability to select a current one
 - [x] Go through code and comment everything
 - [ ] Generate docs site
 - [ ] Add tests, ask agent to detect missing
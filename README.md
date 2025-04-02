# models

Nostr model and local-first reactive relay interface in Dart.

It includes a dummy data implementation that can be used in tests and prototypes and can be overridden in one line of code.

[Purplebase](https://github.com/purplebase/purplebase) will be one such real implementation.

## Design notes

Built on Riverpod providers and StateNotifier notifiers.

Aims to have as much test coverage as possible.

Obviously, API is subject to wild changes at this stage!

Storage with a nostr relay API is at the core of this approach. Querying is done via a family provider where the argument is a nostr filter.

Example:

```dart
ref.watch(nostr(authors: {'a1b2c3'}, kinds: {1}, since: DateTime.now().subtract(Duration(seconds: 5))));
```

Every single event coming through this watcher comes from local storage and never from a relay directly. 

Also, every call by default hits nostr relays (it can be disabled) and saves the returned events to local storage therefore immediately showing up via the watcher - if its filter matches.

The system is aware of previously loaded data so it will add different `since` filters to relay queries appropriately.

To prevent local storage bloat, an eviction policy callback will be made available to clients.

The modelling layer intends to abstract away NIP jargon and be as domain language as possible. It will include a powerful relationship API, such that the following can be performed:

```dart
final note = await storage.findOne<Note>(authors: {'a'});
final Reply reply = await PartialNote('this is cool', replyTo: note).signWith(signer);
print(note.replies.toList());
// And maybe:
await storage.publish(reply, to: {'big-relays'});

// The initial note could of course be retrieved like:
final note = signedInProfile.notes.first;
```

And then:

```dart
final state = ref.watch(query(authors: {'a1b2c3'}, kinds: {1}, and: (_) => {_.replies}));

// ...
children: [
 if (state case StorageData(:final models))
  for (final model in models.cast<Note>())
    for (final reply in model.replies)
      ListTile(
        title: Text('Note ${model.content} has reply: ${reply}'),
      )
]
```

What is important to note here is that the watcher will repaint the widget when any event in storage matches the regular filter. But a reply does not match the regular filter, as it is not a kind 1. That is where the `and` argument comes in, allowing now to repaint upon replies, but not any reply!, only those in a relationship with any matching kind 1 of the regular filter.

Lastly, watching replaceable events will also be a thing:

```dart
final Profile signedInProfile = ref.watch(signedInProfileProvider);
final state = ref.watch(query(signedInProfile, and: (_) => {_.following}));
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
 - [ ] Remote relay configuration
 - [ ] Smart querying using `since` based on local data
 - [ ] Buffered notifiers, with configurable duration
 - [ ] Ability for a watcher to watch a particular subscription (instead of a regular filter)
 - [ ] Allow typed queries `ref.watch(nostr<Note>(authors: {'a'}))` - specialized case, does not allow `kinds` in filter
 - [ ] Allow multiple filters
 - [ ] Eviction policy API, allowing clients to manage the local database size
 - [ ] Add stream support, for those who do not like Riverpod
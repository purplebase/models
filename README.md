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

Also, every call by default hits nostr relays and saves the returned events to local storage (it can be disabled) therefore immediately showing up via the watcher - if its filter matches.

The system is aware of previously loaded data so it will add different `since` filters to relay queries appropriately.

To prevent local storage bloat, an eviction policy callback will be made available to clients.

The modelling layer intends to abstract away NIP jargon and be as domain language as possible. It will include a powerful relationship API, such that the following can be performed:

```dart
final note = await storage.findOne<Note>(authors: {'a'});
final Reply reply = await PartialReply('this is cool').signWith(signer);
note.replies.add(reply);
print(note.replies.toList());
// And maybe:
await storage.publish(reply, to: {'big-relays'});
```

```dart
ref.watch(nostr(authors: {'a1b2c3'}, kinds: {1}, and: (_) => {_.replies}));
```

Relays can be configured in pools, e.g. `storage.configure('big-relays', {'wss://relay.damus.io', 'wss://relay.primal.net'})` and then addressed by label throughout the application; when no relay pools are supplied it is inferred that the outbox model must be utilized.

## TODO

[x] Relay, request and other basic interfaces
[x] Storage API and in-memory implementation
[ ] Use faker data library
[ ] Remote relay configuration
[ ] Smart querying using `since` based on local data
[ ] Popular nostr models, at least those used in Zaplab
[ ] Model relationships
[ ] Ability for a watcher to watch a particular subscription (instead of a regular filter)
[ ] Allow typed queries `ref.watch(nostr<Note>(authors: {'a'}))` - specialized case, does not allow `kinds` in filter
[ ] Allow multiple filters
[ ] Eviction policy API, allowing clients to manage the local database size
[ ] Add stream support, for those who do not like Riverpod
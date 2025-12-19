<!-- HUMAN-ONLY: This document is the source of truth for query provider behavior.
     AI agents must READ but NEVER MODIFY this file.
     All code and tests must conform to this specification.
     Last reviewed: 2025-XX-XX by @maintainer -->

# Query Provider Specification

Expected behavior for all permutations of the `query<E>()`, `queryKinds()`, and `model<E>()` APIs.


## Source Types

`LocalSource()` queries local storage only.

`RemoteSource(relays, stream)` queries relays only.

`LocalAndRemoteSource(relays, stream, cachedFor)` queries both.


## State Transitions

### Loading to Data

```dart
query<Note>(authors: {a})
```

- starts in `StorageLoading` state
- transitions to `StorageData` when models arrive
- never transitions back to `StorageLoading`


### Error Preserves Models

```dart
query<Note>(authors: {a})
```

Given query has models in `StorageData` state, when a relay error occurs:

- transitions to `StorageError`
- preserves existing models in error state
- `state.models` remains accessible


## Local Source

### Local Only

```dart
query<Note>(authors: {a}, source: LocalSource())
```

- returns only models present in local storage
- never opens relay connections
- returns synchronously after initial load


## Remote Source

### Remote Only

```dart
query<Note>(authors: {a}, source: RemoteSource(relays: 'wss://relay.example.com'))
```

- returns only models received from the specified relay
- does not include models already in local storage unless also received from relay
- saves received models to local storage


### Remote Streaming

```dart
query<Note>(authors: {a}, source: RemoteSource(stream: true))
```

- opens subscription to relay
- keeps subscription open after EOSE
- emits new state when new events arrive


### Remote One Time

```dart
query<Note>(authors: {a}, source: RemoteSource(stream: false))
```

- opens subscription to relay
- waits for EOSE before returning
- closes subscription after EOSE


## Local and Remote Source

### Default Behavior

```dart
query<Note>(authors: {a})
```

Equivalent to `LocalAndRemoteSource(stream: true)`:

- immediately returns models from local storage
- opens relay subscription
- merges incoming models with local results
- continues streaming updates after EOSE


### Stream True

```dart
query<Note>(authors: {a}, source: LocalAndRemoteSource(stream: true))
```

- returns immediately with local data (may be empty)
- fetches from relays
- emits new state when relay data arrives
- keeps subscription open indefinitely


### Stream False

```dart
query<Note>(authors: {a}, source: LocalAndRemoteSource(stream: false))
```

- waits for EOSE before returning
- closes subscription after EOSE


### Empty Local No Flash

```dart
query<Note>(authors: {a}, source: LocalAndRemoteSource(stream: true))
```

Given no Notes for `a` in local storage:

- remains in `StorageLoading` state until relay data arrives
- does not emit `StorageData([])` causing empty flash

Given Notes for `a` exist in local storage:

- emits `StorageData` immediately with local models


## Caching

### Fresh Data

```dart
query<Profile>(authors: {a}, source: LocalAndRemoteSource(cachedFor: Duration(hours: 2)))
```

Given Profile for `a` was fetched 1h30m ago:

- returns the cached Profile from local storage
- does not open a relay connection


### Stale Data

```dart
query<Profile>(authors: {a}, source: LocalAndRemoteSource(cachedFor: Duration(hours: 2)))
```

Given Profile for `a` was fetched 2h2m ago:

- returns the cached Profile immediately if exists
- opens relay connection to fetch fresh data
- updates state when fresh data arrives


### No Local Data

```dart
query<Profile>(authors: {a}, source: LocalAndRemoteSource(cachedFor: Duration(hours: 2)))
```

Given no Profile for `a` in local storage:

- opens relay connection immediately
- returns models when received


### Cache Forces No Stream

```dart
query<Profile>(authors: {a}, source: LocalAndRemoteSource(cachedFor: Duration(hours: 2), stream: true))
```

- behaves as `stream: false`
- `cachedFor` overrides `stream` parameter
- closes subscription after EOSE


## Relationships

### Basic Relationship

```dart
query<Note>(
  authors: {a},
  and: (note) => {note.author},
)
```

- fetches Notes for author `a`
- fetches Profile for each Note's author
- makes author accessible via `note.author.value`


### Nested Relationships

```dart
query<Note>(
  authors: {a},
  and: (note) => {
    note.author,
    if (note.author.value != null) note.author.value!.contactList,
  },
)
```

- fetches Notes
- fetches Profiles when Notes arrive
- re-evaluates `and:` callback when Profiles arrive
- fetches ContactLists for those Profiles


### Relationship Source Inheritance

```dart
query<Note>(
  authors: {a},
  source: LocalAndRemoteSource(stream: true),
  and: (note) => {note.author},
)
```

- relationship queries inherit `stream` from parent source


### Relationship Separate Source

```dart
query<Note>(
  authors: {a},
  source: RemoteSource(stream: false),
  andSource: LocalAndRemoteSource(stream: true),
  and: (note) => {note.author},
)
```

- fetches Notes with one time remote query
- fetches Profiles with streaming local and remote query
- keeps Profile subscription open after Note query closes


## Replaceable Models

### Update Same Query

```dart
query<Profile>(authors: {a}, source: LocalAndRemoteSource(stream: true))
```

Given Profile `0:a` exists with name "Alice", when new event arrives with same `kind:pubkey` but name "Alice Updated":

- emits new state with updated Profile
- has exactly 1 model not 2
- model name equals "Alice Updated"


### Update From Different Source

```dart
query<Profile>(authors: {a}, source: LocalAndRemoteSource(stream: true))
```

Given query is active watching Profile for `a`, when unrelated code calls `storage.save(updatedProfileForA)`:

- query receives update via `InternalStorageData`
- query refreshes and emits updated Profile


## Filters

### Where Client Side

```dart
query<Note>(
  authors: {a, b, c},
  where: (note) => note.content.length > 100,
)
```

- fetches Notes from all three authors
- filters to only Notes with content over 100 characters
- applies filter after relay and storage fetch


### Limit

```dart
query<Note>(authors: {a}, limit: 10)
```

- sends `limit: 10` to relay in REQ filter
- returns at most 10 models


### Tags

```dart
query<Note>(tags: {'#t': {'nostr', 'bitcoin'}})
```

- fetches Notes tagged with nostr OR bitcoin
- sends proper `#t` filter to relay


### Since

```dart
query<Note>(authors: {a}, since: DateTime(2024, 1, 1))
```

- fetches Notes created on or after January 1 2024
- sends `since` as unix timestamp to relay


### Until

```dart
query<Note>(authors: {a}, until: DateTime(2024, 12, 31))
```

- fetches Notes created on or before December 31 2024
- sends `until` as unix timestamp to relay


### Search

```dart
query<Note>(search: 'hello world')
```

- sends NIP-50 search filter to relay
- returns Notes matching search term


## Type Inference

### Typed Query

```dart
query<Note>(authors: {a})
```

- automatically adds `kinds: {1}` to filter
- returns only Note models


## queryKinds

### Multi Kind Query

```dart
queryKinds(kinds: {1, 6}, authors: {a})
```

- fetches multiple kinds in single subscription
- returns mixed model types (Note, Repost)
- does not infer kind from type parameter


### With Relationships

```dart
queryKinds(
  kinds: {1, 6},
  authors: {a},
  and: (model) => {model.author},
)
```

- fetches Notes and Reposts
- fetches author Profile for each model
- works with any model type


## model Provider

### Watch Single Model

```dart
model<Note>(existingNote)
```

- watches a specific model instance by ID
- returns updates when model changes
- uses model's ID to construct filter


### With Relationships

```dart
model<Note>(
  existingNote,
  and: (note) => {note.author, note.reactions},
)
```

- watches the specific Note
- fetches author Profile
- fetches Reactions to this Note


### Replaceable Model Updates

```dart
model<Profile>(existingProfile)
```

Given Profile is updated via relay or `storage.save()`:

- emits new state with updated Profile
- maintains single model in state


## Disposal

### Cancels Subscriptions

```dart
final provider = query<Note>(authors: {a}, and: (n) => {n.author})
container.read(provider)
// provider disposed when no longer watched
```

- cancels main Note subscription
- cancels all relationship subscriptions
- no lingering relay connections


## Event Filter

### Filter Events Before Storage

```dart
query<Note>(
  authors: {a},
  schemaFilter: (event) => event['content'].length > 10,
)
```

- receives events from relay
- applies schemaFilter before model construction
- discards events that return false
- only returns events that pass filter


## Connection Handling

### Offline Query Retry

```dart
query<Note>(authors: {a}, source: LocalAndRemoteSource(stream: false))
```

Given device is offline when query is issued:

- subscription is created and connection attempts begin
- EOSE timeout does NOT start until first REQ is successfully sent
- reconnection attempts continue with exponential backoff
- when device comes online, REQ is sent and EOSE timeout starts
- query completes normally after EOSE received

This ensures one-shot queries are retried upon reconnection rather than timing out while still attempting to connect.


### Failed Send Triggers Reconnect

```dart
query<Note>(authors: {a})
```

Given REQ send fails (socket in bad state):

- socket is disconnected
- reconnection is scheduled via backoff
- REQ is resent when connection is re-established


## Edge Cases

### Empty Authors

```dart
query<Note>(authors: {})
```

- returns no models
- does not query relay with empty authors


### Invalid Authors Format

```dart
query<Note>(authors: {'not-valid-hex'})
```

- throws Exception during RequestFilter construction
- never reaches relay


### Null Filters

```dart
query<Note>()
```

- uses type's registered kind automatically
- returns all Notes (unbounded by authors)

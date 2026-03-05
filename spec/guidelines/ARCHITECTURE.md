---
description: Architecture — package layout, dependency rules, key patterns
alwaysApply: true
---

# models — Architecture

## Core Principle

Typed domain objects over raw Nostr JSON, with a reactive local-first query layer that always resolves — models are pure data, storage is an injectable abstraction.

## Package Layout

```
lib/
├── models.dart                  # Single barrel export; everything public lives here
└── src/
    ├── core/
    │   ├── event.dart           # EventBase, ImmutableEvent, ImmutableReplaceableEvent,
    │   │                        #   ImmutableParameterizableReplaceableEvent, PartialEvent
    │   ├── model.dart           # Model (sealed), PartialModel (sealed), RegularModel,
    │   │                        #   ReplaceableModel, ParameterizableReplaceableModel,
    │   │                        #   EphemeralModel — and their Partial counterparts
    │   ├── relationship.dart    # Relationship (sealed), BelongsTo<E>, HasMany<E>, NestedQuery
    │   ├── signer.dart          # abstract Signer, Signable mixin, DummySigner,
    │   │                        #   activePubkeyProvider
    │   ├── encryptable.dart     # Encryptable mixin for NIP-04/44 content
    │   ├── verifier.dart        # abstract Verifier, verifierProvider
    │   ├── internal_models.dart # StorageState hierarchy (StorageLoading, InternalStorageData,
    │   │                        #   StorageError), StorageConfiguration, PublishResponse
    │   └── http.dart            # Minimal HTTP helper (zap invoice fetch, etc.)
    ├── request/
    │   ├── request.dart         # RequestFilter<E>, Request<E>, filter merge logic
    │   └── request_notifier.dart# RequestNotifier (Riverpod AutoDisposeAsyncNotifier),
    │                            #   _RemoteQueryBuffer (batching + merging)
    ├── storage/
    │   ├── storage.dart         # abstract StorageNotifier (StateNotifier<StorageState>),
    │   │                        #   relay resolution, storageNotifierProvider
    │   ├── dummy_storage.dart   # DummyStorageNotifier — pure in-memory, no relay simulation
    │   └── initialization.dart  # Convenience initializer helpers
    ├── models/                  # One file per Nostr kind (note, profile, article, …)
    │   └── *.dart
    ├── nip04/                   # NIP-04 encryption helpers
    ├── nip44/                   # NIP-44 encryption helpers
    ├── nwc/                     # Nostr Wallet Connect command/connection types
    └── utils/
        ├── async.dart           # Async utilities
        └── encoding.dart        # NIP-19 encode/decode, hex helpers
```

## Dependency Rules

- `src/core/` has **no** dependencies on `src/request/`, `src/storage/`, or `src/models/`.
- `src/request/` may import `src/core/` and `src/storage/storage.dart` only.
- `src/storage/` may import `src/core/` and `src/models/` (for registration in `initialize`).
- `src/models/` may import `src/core/` and `src/nip04/`/`src/nip44/` for encryption.
- **Nothing** in `models` may import `purplebase` or any concrete storage backend.
- All files use standard `import`/`export` — **no** `part`/`part of` in new code.

## Key Patterns

### Defining a new Nostr model

```dart
// 1. Immutable model (wraps a signed event)
class Note extends RegularModel<Note> {
  Note.fromMap(super.map, super.ref) : super.fromMap();

  String get content => event.content;
  String? get subject => event.getFirstTagValue('subject');
}

// 2. Mutable partial (for creation/signing)
class PartialNote extends RegularPartialModel<Note> {
  String content = '';
  String? subject;

  @override
  Map<String, dynamic> toMap() => {
    ...super.toMap(),
    'content': content,
    if (subject != null) 'tags': [['subject', subject!]],
  };
}

// 3. Register during StorageNotifier.initialize (called once)
Model.register(
  kind: 1,
  constructor: Note.fromMap,
  partialConstructor: PartialNote.fromMap,
);
```

### Querying — reactive provider

```dart
// In a widget/notifier — auto-disposes when consumer leaves
final notes = ref.watch(
  query<Note>(
    RequestFilter<Note>(authors: {pubkey}, limit: 50),
    source: LocalAndRemoteSource(stream: true),
  ),
);
```

### Querying — one-shot async

```dart
final notes = await storage.query(
  RequestFilter<Note>(authors: {pubkey}).toRequest(),
  source: LocalSource(),
);
```

### Nested relationships (the `and` parameter)

```dart
query<Note>(
  RequestFilter<Note>(authors: {pubkey}),
  and: (note) => {
    note.author.query(),          // BelongsTo<Profile>
    note.reactions.query(),       // HasMany<Reaction>
  },
)
```

### Creating and publishing

```dart
final partial = PartialNote()..content = 'Hello Nostr';
final note = await partial.signWith(signer);
await note.publish();             // sends to relays
await note.save();                // persists locally only
```

### Schema filter (pre-construction rejection)

```dart
query<Note>(
  RequestFilter<Note>(authors: {pubkey}),
  schemaFilter: (raw) => (raw['content'] as String?)?.isNotEmpty == true,
)
```

## Model Hierarchy

```
Model<E> (sealed)
├── RegularModel<E>                        // kinds 1–9999 (non-replaceable)
├── ReplaceableModel<E>                    // kinds 0, 3, 10000–19999
│   └── ParameterizableReplaceableModel<E> // kinds 30000–39999 (has 'd' tag)
└── EphemeralModel<E>                      // kinds 20000–29999
```

Each subtype enforces its kind range at construction time. Replaceable models use composite primary keys (`kind:pubkey` or `kind:pubkey:d-tag`).

## Event Lifecycle

```
PartialModel (mutable, unsigned)
    │  signWith(signer)          ← calls prepareForSigning() for Encryptable
    ▼
Model<E> (immutable, wraps ImmutableEvent)
    │  save()                    ← persists to local SQLite via StorageNotifier
    │  publish(source)           ← sends to relays via StorageNotifier
    ▼
StorageNotifier emits InternalStorageData
    ▼
RequestNotifier re-queries local storage and emits updated list
```

## The `stream` Parameter

Applies only to `RemoteSource` and `LocalAndRemoteSource` (not `LocalSource`).

- `stream: true` (default) — subscriptions remain open indefinitely after EOSE. Incoming models are batched and emitted every `streamingBufferDuration`. The subscription is only closed when the notifier is disposed (consumer leaves).
- `stream: false` — subscriptions close after EOSE (or `responseTimeout`). A one-time fetch.

```dart
// One-time fetch, subscription closes after EOSE
query<Note>(authors: {pubkey}, source: LocalAndRemoteSource(stream: false))

// Stays open, batches new events every streamingBufferDuration
query<Note>(authors: {pubkey}, source: LocalAndRemoteSource(stream: true))
```

## `cachedFor` (on `LocalAndRemoteSource` only)

Skips the remote query and returns local data if the cache is still fresh.

```dart
// Use cached profile for 5 minutes; no relay hit if cache is valid
query<Profile>(authors: {pubkey}, source: LocalAndRemoteSource(cachedFor: Duration(minutes: 5)))
```

Cache eligibility rules (all must hold):
- Filter uses only `authors` and/or `kinds` — no `ids`, `tags`, `search`, `since`, or `until`
- All specified kinds are replaceable (0, 3, 10000–19999, 30000–39999)
- Freshness is tracked per unique `authors+kinds` combination

When `cachedFor` is set, `stream` is forced to `false` regardless of what was passed.

If the query does not meet the eligibility rules, `cachedFor` is silently ignored and the remote query proceeds normally.

## Relay Resolution

The `relays` argument on `RemoteSource` / `LocalAndRemoteSource` accepts:

- A `ws://` or `wss://` URL string — used directly (normalized to canonical form)
- A label string (e.g. `'social'`) — resolves to the active user's signed `RelayList` of the matching kind, falling back to the matching key in `StorageConfiguration.defaultRelays`
- An `Iterable` of any of the above — each item resolved independently
- `null` — falls back to `defaultRelays['default']` (outbox lookup is a future TODO)

Relay resolution happens inside `StorageNotifier.resolveRelays` at query time, before any subscription is opened. By the time a subscription is dispatched, all relay targets are final URLs.

## Request Buffering and Merging

Only **`LocalAndRemoteSource` non-streaming** queries are buffered and merged. Within `requestBufferDuration`, multiple such queries arriving from different `RequestNotifier`s are collected, their filters merged where possible, and sent as fewer relay subscriptions.

`RemoteSource` queries and **streaming** `LocalAndRemoteSource` queries bypass the buffer entirely — they are dispatched immediately to preserve their exact subscription semantics.

## `RemoteSource` — Exclusion of Pre-Existing Local Data

`RemoteSource` emits only models that arrived via the current subscription. Models already in local storage that happen to match the request are excluded. This is enforced via an internal `_arrivedViaSubscription` set in `RequestNotifier`.

## Query Execution Flow

```
RequestFilter<E>
    │ .toRequest()
    ▼
Request<E>  ──────────────────────────────────────────────────┐
    │                                                          │
    │ LocalSource                  LocalAndRemoteSource        │ RemoteSource
    ▼                              ▼                           ▼
querySync() → immediate flush   querySync() → flush if        relay.subscribe()
                                non-empty, then remote        → save to local
                                                              → flush on EOSE
                                        ↓ (both paths)
                                  schemaFilter (raw event)
                                        ↓
                                  model construction
                                        ↓
                                  where filter (typed)
                                        ↓
                                  List<E> emitted
```

Remote queries from multiple `RequestNotifier`s are batched within `requestBufferDuration` and merged into fewer relay subscriptions before dispatch.

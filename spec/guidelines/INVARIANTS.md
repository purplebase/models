---
description: Non-negotiable invariants — query resolution, data integrity, model purity, signing
alwaysApply: true
---

# models — Invariants

These are non-negotiable. Violating any invariant is a bug — no tradeoffs or exceptions.

## Query Resolution

- Every query MUST resolve to a terminal state (data, empty list, or error) within a bounded time. A consumer must never hang indefinitely.
- `LocalSource` flushes immediately, even when the result is empty.
- `LocalAndRemoteSource` flushes local results immediately if non-empty; remote results flush on EOSE or `responseTimeout`, whichever comes first.
- `RemoteSource` flushes on EOSE or `responseTimeout`. If no relay responds, the query still resolves (empty or error).
- The `requestBufferDuration` batching window must not delay a query beyond its configured timeout.

## Data Integrity

- `ImmutableEvent` is truly immutable after construction — no field may be mutated.
- A `Model` wrapping an `ImmutableEvent` must never be modified in place; create a new `PartialModel` and sign it instead.
- Kind/subtype mismatch (e.g., kind 1 wrapped in `ReplaceableModel`) throws at construction — it is never silently accepted.
- `ParameterizableReplaceableModel` requires a `d` tag; construction without one throws.
- Addressable IDs (`kind:pubkey` or `kind:pubkey:d-tag`) are the canonical primary keys for replaceable models — raw event `id` is never used as PK for those types.

## Model Purity

- `Model` and `PartialModel` constructors must not perform I/O, network calls, or Riverpod reads beyond the `StorageReader`/`Ref` passed in.
- `processMetadata()` is the only place expensive decoding (e.g., bolt11 parsing) may run, and its result is cached in `ImmutableEvent.metadata`.
- Models must not hold references to `BuildContext` or any Flutter widget tree object.

## Registry

- A model kind must be registered via `Model.register(...)` before any query or construction for that kind is attempted. Accessing an unregistered kind throws — it is never silently ignored.
- Registration is idempotent: calling `Model.register` twice for the same type with the same kind is a no-op; calling it with a different kind is a bug.

## Signing

- `signWith(signer)` is the only path from `PartialModel` to `Model`. Direct construction of `ImmutableEvent` from unverified data is only permitted inside `StorageNotifier` implementations (incoming relay events).
- If a model implements `Encryptable`, `prepareForSigning(signer)` MUST be called (and awaited) before the event is signed. Skipping encryption is a bug.
- `DummySigner` is test-only. It must never appear in production code paths.

## Streaming

- `stream: false` subscriptions MUST close after EOSE (or `responseTimeout`). They must never remain open past that point.
- `stream: true` subscriptions MUST remain open until the notifier is disposed or `cancel` is called. They must never close on their own after EOSE.
- When `cachedFor` is set on `LocalAndRemoteSource`, `stream` is forced to `false` — the explicit `stream` argument is ignored.

## Caching (`cachedFor`)

- `cachedFor` is only eligible when the filter uses exclusively `authors` and/or `kinds`, all specified kinds are replaceable, and none of `ids`, `tags`, `search`, `since`, or `until` are present.
- When the cache is valid, the remote query MUST be skipped entirely — no relay subscription is opened.
- When the query does not meet eligibility rules, `cachedFor` MUST be silently ignored — it is never an error.
- Cache freshness is tracked per unique `authors+kinds` combination. Saving any model clears all cache timestamps.

## Relay Resolution

- Relay resolution MUST complete before any subscription is dispatched. A subscription is never opened against an unresolved label.
- A label string resolves to the active user's signed `RelayList` first, then falls back to `StorageConfiguration.defaultRelays`. If neither yields URLs, the query proceeds with an empty relay set (which will resolve as empty or timeout).
- `null` relays falls back to `defaultRelays['default']` (outbox lookup is not yet implemented).

## Request Buffering

- Only `LocalAndRemoteSource` non-streaming queries enter the `requestBufferDuration` buffer. `RemoteSource` and streaming `LocalAndRemoteSource` queries bypass it.
- The buffer MUST NOT delay a query beyond `responseTimeout`. If `requestBufferDuration >= responseTimeout`, the query still resolves at `responseTimeout`.

## Relationships

- Relationship accessors (`BelongsTo.value`, `HasMany.toList()`) are synchronous reads from local storage only — they never block on network.
- Empty relationship results are not cached; only non-empty results are cached per `cacheVersion`. This ensures cold-start scenarios where related data arrives after the parent model are handled correctly.

## Error Handling

- All errors must be wrapped with context (which request, which kind, which relay).
- Errors must propagate up via `StorageState` (`StorageError`) — never swallowed silently.
- A relay error for one subscription must not cancel unrelated subscriptions.

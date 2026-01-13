# Query Specification

Queries take `Request`s (or `RequestFilter`s) and `Source`s to understand *what* and *where/how* to query.

This is a local-first system: every model emitted comes from local storage and **never** directly from a remote source.

## Query Providers vs storage.query

**Query providers** (`query`, `queryKinds`, `model`) are reactive and auto-disposable, notifiers call `cancel` on the underlying subscriptions, closing the relay connections for that query.

In contrast, **async mode** with `storage.query` returns a future and resolves once, after all subscriptions complete or time out.

The optional `subscriptionPrefix` makes subscription IDs readable for debugging (e.g., `app-detail-123456` instead of `sub-123456`).

Due to the nature of query calls (including nested ones), queries will be buffered during  `requestBufferDuration` and requests merged before sent to remotes, preventing flooding relays.

## Flushing

Models from local storage are not emitted through a notifier as they are saved, but only at certain points in time flushed in batches. In this document we use the term "flush" for simplicity, even if technically the word is "emit" for `query` provider and "return" for `storage.query` async mode.

 - EOSE: flush for every EOSE received or on `responseTimeout`, whatever comes first. In async mode wait for all EOSEs/timeouts to flush once. Every time an EOSE flush is mentioned hereafter, assume it includes timeouts as the system is designed to never hang
 - Stream buffers: applicable to subscriptions, flush every `streamingBufferDuration`

## Sources

- `LocalSource`: query models in local storage only; flushes immediately, even if empty

- `LocalAndRemoteSource`: query models in local storage, flush immediately only if non-empty, then open remote subscriptions and flush new models

- `RemoteSource`: open remote subscriptions; incoming models are saved to local storage, then flushed. Only models that arrived via this exact subscription are included—pre-existing local data matching the request is excluded.

If no source is provided, `defaultQuerySource` is used.

### Relay Resolution

Remote sources take a `relays` argument which can be:

- A URL prefixed with `ws://` or `wss://` (used directly)
- A label string (resolves to the active user's signed `RelayList` first, then falls back to `defaultRelays` in configuration)
- An iterable containing any of the above

By the time a query is issued, all relays must be resolved to their final URL.

## The `stream` Parameter

Async mode is naturally always non-streaming and flushes once.

The parameter applies only on remote sources (`LocalAndRemoteSource`, `RemoteSource`).

For non-streaming queries, models are flushed only at EOSE, after which subscriptions close. Subscriptions do not wait for each other—if querying with a subscription to 3 different relays, 3 separate emissions will occur.

```dart
// One-time fetch, subscriptions close after EOSE (or timeout)
query<Note>(authors: {pubkey}, source: LocalAndRemoteSource(stream: false))
```

With `stream=true`, subscriptions remain open indefinitely (until manually canceled or process is killed). After EOSE, incoming models are batched and emitted every `streamingBufferDuration` configurable duration.

## Nested Queries

Nested queries fetch relationships of models from the outer query. The `and` callback receives each model and returns a `Set<NestedQuery>` via the `.query()` method on relationships.

```dart
query<App>(
  authors: {pubkey},
  source: LocalSource(),
  and: (app) => {
    app.latestRelease.query(source: LocalAndRemoteSource(stream: false)),
    app.author.query(source: RemoteSource(relays: {'social'})),
    app.appStacks.query(),
  },
)
```

By default, nested queries inherit `source` and `subscriptionPrefix` from the outer query. Override per-relationship as shown above.

On every outer flush, relationships are recomputed. New relationships not already streaming are issued; non-streaming relationships are re-issued each flush. Request merging via `requestBufferDuration` applies.

Arbitrary nesting is supported. Each level honors its own parameters.

```dart
query<App>(
  authors: {pubkey},
  and: (app) => {
    app.latestRelease.query(
      source: LocalAndRemoteSource(stream: false),
      and: (release) => {release.signer.query()}
    ),
  },
)
```

Errors in nested queries emit `StorageError` on the outer notifier, preserving outer models loaded before the error along with the nested exception.

## Filtering

`schemaFilter` evaluates events before model construction and rejected ones are permanently deleted from local storage. Use this for events that under no circumstance should be kept.

```dart
// Only keep notes longer than 10 characters
query<Note>(
  authors: {pubkey},
  schemaFilter: (event) => (event['content'] as String).length > 10,
)
```

The `where` filter prevents events from showing in results, this happens after model construction (relationships can be used in the rejection logic) and not removed from local storage.

```dart
// Only keep notes whose author's name is longer than 10 characters
query<Note>(
  authors: {pubkey},
  where: (note) => note.author.value.name.length > 10,
)
```

## Caching

When a query consists of only author and/or replaceable kinds (no other filter fields), `cachedFor` allows returning from local storage without querying remote for the specified duration.

```dart
// Use cached profile for 5 minutes
query<Profile>(authors: {pubkey}, source: LocalAndRemoteSource(cachedFor: Duration(minutes: 5)))
```

If the query has other filter fields (tags, ids, search, until), caching is silently ignored.

Cache freshness is tracked per unique author+kind combination. When the cache expires, the next query with `cachedFor` will hit remote relays again.

## State Transitions

The loading phase (`StorageLoading`) will never exceed `responseTimeout`. All subscriptions will have flushed by then.

`StorageLoading` must transition to `StorageData` or `StorageError`, never remaining in loading state—even with zero results.

For `LocalSource`, transition immediately. For remote sources, if local storage is empty, flush on first EOSE.

When errors occur a `StorageError` is emitted, the system has already attempted recovery—no automatic retries follow. As a `StorageState` instance it preserves any models successfully loaded before the error.

# Models Query Specification

Queries take `Request`s (or `RequestFilter`s) and `Source`s to understand *what* and *where/how* to query.

This is a local-first system: every model emitted comes from local storage and **never** directly from a remote source.

## Sources

- `LocalSource`: query models in local storage only; emit immediately, even if empty

- `LocalAndRemoteSource`: emit local models immediately if non-empty, then open remote subscriptions and emit incoming models in batches at each EOSE (or timeout)

- `RemoteSource`: open remote subscriptions and emit *exactly* the models that came in via those subscriptions (not pre-existing local data)

If no source is provided, `StorageConfiguration#defaultQuerySource` is used.

```dart
// Local only
final notes = await storage.query(req, source: LocalSource());

// Local + remote (default)
final notes = await storage.query(req, source: LocalAndRemoteSource());

// Remote only (ignore pre-existing local data)
final notes = await storage.query(req, source: RemoteSource(relays: 'wss://relay.example.com'));
```

### Relay Resolution

Remote sources take `relays` which can be:

- A URL prefixed with `ws://` or `wss://` (used directly)
- A label string (resolves to the active user's signed `RelayList` first, then falls back to `defaultRelays` in configuration)
- An iterable containing any of the above

By the time a query is issued, all relays must be resolved to their final URL.

## The `stream` Parameter

Applies only to remote sources.

With `stream=false`, models are emitted in batches at each EOSE (or timeout), after which subscriptions close. Subscriptions do not wait for each other—if querying with a subscription to 3 different relays, 3 separate emissions will occur.

```dart
// One-time fetch, subscriptions close after EOSE (or timeout)
query<Note>(authors: {pubkey}, source: LocalAndRemoteSource(stream: false))
```

With `stream=true`, subscriptions remain open indefinitely (until manually canceled or process is killed). After EOSE, incoming models are batched and emitted every `StorageConfiguration#streamingBufferWindow`.

```dart
// Keep streaming new notes as they arrive
query<Note>(authors: {pubkey}, source: LocalAndRemoteSource(stream: true))
```

## Relationship Queries (`and`)

Relationships depend on models from the main query. By default they inherit the source, but can specify their own via `andSource`.

```dart
// Fetch apps locally, but fetch their releases from remote
query<App>(
  authors: {pubkey},
  source: LocalSource(),
  andSource: LocalAndRemoteSource(stream: false),
  and: (app) => {app.latestRelease},
)
```

Every time new models arrive from the main query, relationship queries are issued for those new models (existing relationship queries are not re-issued). The `stream` behavior applies: if false, relationship subscriptions close after EOSE; if true, they remain open.

## Filtering

`schemaFilter` discards events before model construction, applied to both local and remote data. The `where` filter prevents events from showing, this is after model construction, which is more expensive but relationships can be used. 

```dart
// Only keep notes longer than 10 characters
query<Note>(
  authors: {pubkey},
  schemaFilter: (event) => (event['content'] as String).length > 10,
)
```

## Caching

When a query consists of only author and/or replaceable kinds (no other filter fields), `cachedFor` allows returning from local storage without querying remote for the specified duration.

```dart
// Use cached profile for 5 minutes
query<Profile>(authors: {pubkey}, source: LocalAndRemoteSource(cachedFor: Duration(minutes: 5)))
```

If the query has other filter fields (tags, ids, search, until), caching is silently ignored.

## State Transitions

The loading phase (`StorageLoading`) will never exceed `StorageConfiguration#responseTimeout`. All subscriptions will have responded with EOSE or timed out by then.

`StorageLoading` must transition to `StorageData` or `StorageError`, never remaining in loading state—even with zero results.

For `LocalSource`, transition immediately. For remote sources, if local storage is empty, wait for first EOSE or timeout before transitioning.

When errors occur, a `StorageError` is emitted.

## Query Providers vs storage.query

**Query providers** (`query`, `queryKinds`, `model`) are reactive—they emit multiple times as data arrives:

```dart
// Emits each time an EOSE batch arrives
ref.watch(query<Note>(authors: {pubkey}))
```

In contrast, **`storage.query`** returns a future and resolves once, after all subscriptions complete (or time out):

```dart
Future<List<E>> query<E extends Model<dynamic>>(
  Request<E> req, {
  Source? source,
  String? subscriptionPrefix,
});

// Waits for all EOSEs, returns all models in one lump
final notes = await storage.query(req);
```

The optional `subscriptionPrefix` makes subscription IDs readable for debugging (e.g., `app-detail-123456` instead of `sub-123456`).

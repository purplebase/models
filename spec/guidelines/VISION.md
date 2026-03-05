---
description: Product vision — what models is, who it serves, what success means
alwaysApply: true
---

# models — Vision

## What models Is

A pure-Dart library that maps Nostr events to typed domain objects and provides a reactive, local-first query/storage abstraction — so app code never touches raw JSON or relay wire protocol.

## Who Uses It

- **App developers** building Nostr clients or tools on Flutter/Dart who want typed models, reactive queries, and signer integration without writing boilerplate.
- **purplebase** (the concrete storage backend) which implements `StorageNotifier` on top of SQLite + a relay pool, and depends on `models` for all type definitions and the storage contract.

## What Success Means

- A developer can define a new Nostr event kind in ~20 lines (model class + registration) and immediately query, save, and publish it.
- Queries always resolve — no consumer ever hangs waiting for data that will never arrive.
- Models are pure data: constructing or comparing them requires no network, no database, no Riverpod container.
- Relationship traversal (`author`, `reactions`, `zaps`, custom `BelongsTo`/`HasMany`) works synchronously from local cache and transparently triggers remote fetches when needed.

## Non-Goals

- **No concrete storage implementation** — `models` ships only `DummyStorageNotifier` (in-memory, for tests). Real persistence lives in `purplebase`.
- **No relay connection logic** — relay pool, WebSocket management, and SQLite are all in `purplebase`.
- **No UI layer** — `models` exposes Riverpod providers but has no widgets or platform channels.
- **No server-side / web** — targets mobile and desktop Dart only.

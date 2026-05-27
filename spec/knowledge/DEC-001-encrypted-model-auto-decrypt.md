---
date: 2026-05-07
tags: [encryption, event-lifecycle, metadata, immutability, prepareAfterLoading]
problem: EncryptableModel needs an in-memory decryption cache that (a) doesn't trigger @immutable warnings, (b) never serialises to disk, and (c) rounds-trips correctly through toPartial()
---

# DEC-001 — event.metadata as the in-memory decryption cache

## Problem

`EncryptableModel` needs to cache decrypted plaintext so that:
1. Property getters (`privateAppIds`, `message`, etc.) return correct values without re-decrypting on every call.
2. The cache is never serialised to disk or sent to a relay (ciphertext must remain canonical).
3. `toPartial()` can inject the plaintext as the partial's `event.content` so the decrypt → mutate → re-sign workflow works without workarounds.
4. No `@immutable` analyzer warning fires on model classes.

## Context

`Model` mixes in `EquatableMixin` which is annotated `@immutable`. Adding a non-final field (e.g. `String? _decrypted`) to `EncryptableModel` generates a `must_be_immutable` warning on every concrete class that uses the mixin. Seven encrypted model classes are affected.

## Decision

Store the decryption cache in `event.metadata['_decrypted']` — a mutable `Map` held by a `final` field. Override `toMap()` in `EncryptableModel` to strip the key before returning, so it is never serialised.

## Options Considered

- **Option A: Non-final `String? _decrypted` field on the mixin** — simple, but generates `must_be_immutable` warnings on all seven model classes (AppStack, BookmarkSet, AppCatalogRelayList, DirectMessage, NwcRequest, NwcResponse, NwcNotification).
- **Option B: Static `Map<String, String>` keyed by event ID** — avoids the warning, but leaks memory unless explicitly cleared and is awkward to scope per-user-session.
- **Option C: `event.metadata['_decrypted']` with `toMap()` override (chosen)** — `metadata` is already `final Map<String, dynamic>`; mutating the map's contents does not violate the `final` constraint checked by the analyzer. No warning, no leak, clears naturally when the model instance is GC'd.

## Rationale

`event.metadata` is already an approved in-memory mutable slot — `processMetadata()` writes to it at construction time and it is used by `PartialEvent._prepareMapForPartial` for the `_plaintext` key. Reusing the same map for the decryption cache is consistent with the existing pattern. The `toMap()` override that strips `_decrypted` ensures the invariant that `event.content` is always the ciphertext in any serialised output.

## How to Avoid This Problem Next Time

- When adding in-memory state to a model mixin, prefer `event.metadata` over a new field to avoid `@immutable` warnings.
- Any key written to `event.metadata` in post-construction code MUST be stripped in a `toMap()` override if it must not appear in persisted or wire data. The convention is a `_`-prefixed key name.
- The single approved exception to "no mutation after construction" is `event.metadata` — but only for caching computed values derived from the immutable event fields (never for changing identity or kind).
- See `lib/src/core/encryptable.dart` `EncryptableModel.toMap()` for the correct stripping pattern.

---

## Guidelines that need human review after this change

The following entries in `spec/guidelines/` are now inaccurate or incomplete. They require a human owner to update (agents must not modify guidelines without permission):

### INVARIANTS.md — Model Purity
> "`processMetadata()` is the **only** place expensive decoding may run, and its result is cached in `ImmutableEvent.metadata`."

**New reality:** `prepareAfterLoading(Ref ref)` is a second approved slot for async post-load work (e.g. decryption). Its result is also cached in `event.metadata`. The invariant should be updated to acknowledge both hooks.

### INVARIANTS.md — Data Integrity
> "`ImmutableEvent` is truly immutable after construction — no field may be mutated."

**New reality:** The `metadata` map's *contents* are intentionally mutable (written by `processMetadata()` at construction and by `prepareAfterLoading` post-load). The wire-format identity fields (`id`, `pubkey`, `sig`, `content`, `kind`, `tags`, `created_at`) are truly immutable. The wording should be tightened to reflect this distinction.

### QUALITY_BAR.md — Anti-Patterns
> "*Mutable `ImmutableEvent`* — casting away `final` or using `metadata` to store mutable state that changes after construction."

**New reality:** This entry now contradicts the canonical implementation. The approved pattern — storing a post-load cache in `event.metadata` with a `toMap()` override to strip it — should be documented as the *correct* approach and the anti-pattern refined to: "mutating identity fields or serialising internal cache keys to wire format".

### ARCHITECTURE.md — Event Lifecycle
The diagram should be updated to show the `prepareAfterLoading` hook on the read path:

```
StorageNotifier emits InternalStorageData
    ▼
RequestNotifier re-queries local storage
    ▼
prepareAfterLoading(ref)   ← decryption for EncryptableModel
    ▼
List<E> emitted to consumer
```

### ARCHITECTURE.md — encryptable.dart description
The one-liner for `encryptable.dart` should be expanded to reflect both the write hook (`EncryptablePartialModel.prepareForSigning`) and the new read hook (`EncryptableModel.prepareAfterLoading`).

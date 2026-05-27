# WORK-001 — Auto-decrypt Encrypted Models After Loading

**Feature:** Ergonomic encrypted model decryption
**Status:** Complete

## Problem

Encrypted models (`AppStack`, `BookmarkSet`, `AppCatalogRelayList`, `DirectMessage`, `NwcRequest/Response/Notification`) store ciphertext in `event.content`. After signing, their private-field getters silently return empty results because `jsonDecode(ciphertext)` fails. Consumers must manually call `signer.nip44Decrypt(model.content, pubkey)` and parse JSON themselves — no clean API exists.

Additionally, `toPartial()` copies the ciphertext into the partial, making the decrypt-mutate-resign workflow broken without workarounds.

## Approach

Symmetric to the existing `prepareForSigning` hook on `PartialModel`, add a `prepareAfterLoading(Ref ref)` async hook on `Model` (no-op by default). `EncryptableModel` overrides it to:

1. Resolve the correct signer from the Riverpod ref (self-encryption: signer for `event.pubkey`; asymmetric DM/NWC: try sender's signer, then recipient's).
2. Decrypt into `event.metadata['_decrypted']` as an in-memory cache. `toMap()` strips this key so plaintext is never written to disk or relay wire.
3. `toPartial()` is overridden to inject `_decrypted` as the partial's content when present.
4. All private-field getters (`privateAppIds`, `privateBookmarks`, `privateRelays`, `message`, `getContentMap`) use `plaintext ?? content` so they work transparently after decryption and gracefully when no signer is available.
5. `RequestNotifier` emits query results first, then schedules `prepareAfterLoading` as bounded post-load enrichment. Successful enrichment re-emits with a state revision bump so listeners can react to `isDecrypted`.

`event.content` and `toMap()` are never modified — the ciphertext remains canonical for disk persistence and relay publishing.

## Tasks

- [x] 1. Create work packet
  - Files: `spec/work/WORK-001-auto-decrypt.md`
- [x] 2. Add `prepareAfterLoading` no-op to `Model`
  - Files: `lib/src/core/model.dart`
- [x] 3. Rework `EncryptableModel`: cache in `event.metadata['_decrypted']`, `plaintext`, `isDecrypted`, `prepareAfterLoading`, `toMap` override (strips cache key), `toPartial` override
  - Files: `lib/src/core/encryptable.dart`
- [x] 4. Wire `prepareAfterLoading` into `RequestNotifier` as non-blocking post-load enrichment
  - Files: `lib/src/query/request_notifier.dart`, `lib/src/storage/storage_state.dart`
- [x] 5. Update encrypted model getters to use `plaintext ?? content`
  - Files: `lib/src/models/app_stack.dart`, `bookmark_set.dart`, `relay_list.dart`, `direct_message.dart`, `nwc.dart`
- [x] 6. Tests: encrypted local queries resolve before decryption, then re-emit after delayed decryption; hanging decryption does not block local query resolution
  - Files: `test/core/encryptable_test.dart`
- [x] 7. `dart analyze` — no issues

## Test Coverage

| Scenario | Expected | Status |
|----------|----------|--------|
| `prepareAfterLoading` with matching signer | `isDecrypted == true`, `plaintext` == original | [ ] |
| `prepareAfterLoading` with no signer registered | `isDecrypted == false`, getters return `[]`/`{}` | [ ] |
| `privateAppIds` before `prepareAfterLoading` | returns `[]` (encrypted ciphertext not valid JSON) | [ ] |
| `privateAppIds` after `prepareAfterLoading` | returns correct decrypted list | [ ] |
| `toPartial()` on decrypted model | partial.event.content == plaintext, re-signing encrypts | [ ] |
| `toPartial()` on non-decrypted model | partial.event.content == ciphertext (unchanged) | [ ] |
| `toMap()` always returns ciphertext | `_decrypted` never appears in serialized output | [ ] |
| DM: sender signer decrypts | plaintext accessible from sender's perspective | [ ] |
| DM: recipient signer decrypts | plaintext accessible from recipient's perspective | [ ] |
| NWC: NIP-04 decryption via prepareAfterLoading | `getContentMap()` returns correct map | [ ] |
| RequestNotifier: first emit happens before delayed decryption | query resolves with `isDecrypted == false` | [x] |
| RequestNotifier: post-load enrichment succeeds | second emit has `isDecrypted == true` and a higher revision | [x] |
| RequestNotifier: decryption hangs | query still resolves without waiting for signer decrypt | [x] |

## Decisions

### 2026-05-06 — Use `event.metadata['_decrypted']`, not a mutable model field

**Context:** Needed an in-memory plaintext cache that doesn't survive serialization and does not trip `@immutable` analyzer checks.
**Options:** (A) Separate `String? _decrypted` field on the mixin. (B) Static cache keyed by event ID. (C) `event.metadata['_decrypted']` stripped by `toMap()`.
**Decision:** Option C.
**Rationale:** A mutable mixin field triggers analyzer warnings on immutable models. A static cache risks leaks. `event.metadata` is already copied per model instance and can be stripped centrally from serialized output.

### 2026-07-07 — Decryption is post-load enrichment, not query resolution

**Context:** Awaiting signer decryption before `_emit()` can violate the invariant that every query resolves within bounded time, especially for `LocalSource`.
**Decision:** `RequestNotifier` emits models immediately, then schedules `prepareAfterLoading` in the background with `responseTimeout`. Successful enrichment re-emits the same models with a `StorageState.revision` bump.
**Rationale:** Consumers can watch `isDecrypted` while the query lifecycle remains independent from signer latency or failure.

### 2026-05-06 — Single `prepareAfterLoading` override handles all encryption patterns

**Context:** Self-encryption (AppStack etc.) and asymmetric (DM, NWC) have different signer lookup logic.
**Options:** (A) Each model overrides `prepareAfterLoading`. (B) `EncryptableModel` handles both via `getEncryptionPubkey() == event.pubkey` check.
**Decision:** Option B.
**Rationale:** All information needed to determine which signer to use is already encoded in `getEncryptionPubkey()`. No subclass overrides needed — consistent, less surface area.

## Progress Notes

**2026-05-06:** Work packet created. Beginning implementation.

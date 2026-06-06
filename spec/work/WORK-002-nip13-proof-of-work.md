# WORK-002 — NIP-13 Proof of Work

**Feature:** Opt-in NIP-13 proof-of-work during signing
**Status:** Complete

## Problem

The library can construct and sign NIP-01 events but cannot mine or validate
NIP-13 proof of work. Mining must run after signing preparation, because
encryption mutates event content and therefore changes its ID, and before the
low-level signer creates the signature.

## Approach

Add bounded, opt-in proof-of-work to the high-level `signWith` APIs. A concrete
signer orchestration method prepares each partial, mines its final event fields,
signs it, and verifies that the signer returned the mined proof unchanged.
Keep `Signer.sign` as the compatible low-level API for already-prepared input.

Mining preserves caller-provided timestamps, replaces stale `nonce` tags, yields
between batches, and restores original tags if its time or attempt budget is
exhausted.

## Tasks

- [x] 1. Create work packet
  - Files: `spec/work/WORK-002-nip13-proof-of-work.md`
- [x] 2. Implement NIP-13 options, result, validation, and bounded mining
  - Files: `lib/src/nip13/nip13.dart`, `lib/models.dart`
- [x] 3. Integrate mining into high-level signing
  - Files: `lib/src/signer/signer.dart`, `lib/src/core/model.dart`
- [x] 4. Add focused NIP-13 and signing-order tests
  - Files: `test/core/nip13_test.dart`
- [x] 5. Run formatting, analysis, and tests
- [x] 6. Self-review against INVARIANTS.md

## Test Coverage

| Scenario | Expected | Status |
|----------|----------|--------|
| Official NIP-13 difficulty examples | Leading zero bits counted correctly | [x] |
| Malformed event ID | `FormatException` | [x] |
| Low-difficulty mining | One valid committed `nonce` tag | [x] |
| Existing nonce tags | Replaced without duplicates | [x] |
| Attempt exhaustion | Typed error and original tags restored | [x] |
| Batch mining failure | Earlier partial tags are also restored | [x] |
| Single `signWith` with PoW | Signed event meets requested target | [x] |
| Encrypted partial with PoW | Encryption occurs before mining | [x] |
| Iterable `signWith` | Every partial is prepared and mined | [x] |
| Signer changes mined fields | Post-sign validation rejects result | [x] |
| Commitment validation | Missing, malformed, low, and false targets rejected | [x] |

## Decisions

### 2026-07-09 — Mine through high-level signing orchestration

**Context:** `Signer.sign` is implemented by downstream signers and currently
accepts already-prepared partials.
**Options:** Change the abstract signer API, mine explicitly before signing, or
add optional PoW to high-level signing.
**Decision:** Add optional PoW to `signWith` and a concrete
`Signer.prepareAndSign` orchestrator.
**Rationale:** This guarantees encryption → mining → signing order without
breaking external signer implementations.

### 2026-07-09 — Preserve `created_at`

**Context:** NIP-13 recommends, but does not require, refreshing `created_at`
during mining.
**Decision:** Preserve the partial's timestamp.
**Rationale:** Models supports explicit historical timestamps and `toPartial()`
round trips. Callers can set a fresh timestamp before signing when desired.

### 2026-07-09 — Require two mining bounds

**Context:** Target-only mining can run indefinitely and block a caller.
**Decision:** Every mining request has a positive timeout and maximum attempt
count, and yields after a bounded batch.
**Rationale:** Failure is deterministic and UI isolates remain responsive.

## Spec Issues

_None._

## Progress Notes

**2026-07-09:** Revised proposal approved. Work packet created.

**2026-07-09:** Implemented bounded mining, signing orchestration, batch
rollback, and post-sign verification. `dart analyze` and the full `dart test`
suite pass.

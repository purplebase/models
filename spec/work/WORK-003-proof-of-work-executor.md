# WORK-003 — Proof-of-Work Executor

**Feature:** FEAT-001-proof-of-work-executor.md
**Status:** Complete

## Tasks

- [x] 1. Add the executor seam to NIP-13 options
- [x] 2. Route high-level signing through the selected executor
- [x] 3. Preserve rollback and post-sign validation
- [x] 4. Cover executor success, failure, and cancellation
- [x] 5. Run analysis and tests
- [x] 6. Self-review against INVARIANTS.md

## Test Coverage

| Scenario | Expected | Status |
|----------|----------|--------|
| Executor mining | Prepared event is delegated | [x] |
| Executor failure | No event is signed; tags restored | [x] |
| Signer mutation | Mined ID mismatch is rejected | [x] |
| No executor | Existing miner remains compatible | [x] |

## Decisions

### 2026-07-13 — Inject execution, keep mining pure

**Context:** Flutter must not run NIP-13 hash loops on its main isolate, while
models must remain independent of concrete isolate implementations.
**Decision:** Models defines an executor interface; a downstream adapter owns
the worker isolate.
**Rationale:** Keeps signing order and validation centralized without coupling
the domain package to Flutter or Purplebase.

## Spec Issues

_None_

## Progress Notes

**2026-07-13:** Work started for Zapstore's device-private event contract.

**2026-07-13:** Executor seam, rollback tests, analysis, and full test suite
completed successfully.

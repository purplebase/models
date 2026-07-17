# FEAT-001 — Proof-of-Work Executor

## Goal

Allow high-level model signing to delegate NIP-13 mining to a cancellable
executor while preserving encryption → mining → signing → verification order.

## Non-Goals

- Choosing application-specific PoW difficulty
- Owning isolates or platform lifecycle inside models
- Changing low-level signer implementations

## User-Visible Behavior

- Applications may mine off their UI isolate.
- Cancellation and mining limits fail explicitly without signing.
- Callers without an executor retain the existing bounded in-isolate miner.

## Edge Cases

- Executor cancellation restores the original event tags.
- Executor failure never produces a signed event.
- A signer that mutates mined fields is rejected.
- Batch failure restores earlier partials.

## Acceptance Criteria

- [ ] `ProofOfWorkOptions` can select an executor.
- [ ] Signing preparation completes before executor mining starts.
- [ ] The signed event ID matches the executor's mined ID.
- [ ] Failure and cancellation leave partials reusable.
- [ ] Existing callers remain source-compatible.

---
description: Quality expectations — when to spec, testing, anti-patterns, AI workflow
alwaysApply: true
---

# models — Quality Bar

## When to Create a Feature Spec

Create a spec if the work:

- Touches query lifecycle, flushing, or source-handling logic
- Changes how relationships are discovered, cached, or invalidated
- Modifies the signing or encryption flow
- Adds or removes a field on `RequestFilter`, `Request`, `StorageConfiguration`, or `StorageState`
- Introduces a new model base type or changes kind-range enforcement
- Could regress existing behavior (especially "always resolves" guarantees)

**Skip the spec** if:

- Adding a new Nostr model kind (new file in `src/models/`, register in `initialize`) — follow the existing pattern
- Pure cosmetic changes (rename, doc comment, formatting)
- Bug fix with an obvious, isolated cause
- Dependency update with no API changes

When in doubt, create a spec. The overhead is low.

## Testing

- All query logic must be tested with `DummyStorageNotifier` — no real SQLite, no real WebSockets.
- Use `DummySigner` / `partial.dummySign()` for tests that need signed models.
- Tests must not make real network calls. Mock or stub any relay interaction.
- Test both the "data found" and "empty result" paths for every query variant.
- Test that `LocalSource` flushes immediately even when empty.
- Test that EOSE timeout causes a flush (not a hang) when no relay responds.
- Relationship cache invalidation: verify that saving a new model causes stale cached relationships to refresh.
- Test that `stream: false` closes the subscription after EOSE and emits no further updates.
- Test that `stream: true` keeps the subscription open after EOSE and continues emitting batched updates.
- Test that `cachedFor` returns local data without opening a relay subscription when the cache is fresh.
- Test that `cachedFor` is silently ignored (remote query proceeds) when the filter includes `ids`, `tags`, `search`, `since`, or `until`.
- Test that `cachedFor` forces `stream: false` even when `stream: true` is passed explicitly.
- Test that `RemoteSource` excludes models already in local storage that match the filter — only models arriving via the subscription are emitted.

## Implementation Expectations

- Follow the existing pattern in the nearest model file before inventing a new approach.
- New model kinds go in `src/models/<name>.dart` — one file per kind.
- Do not add Riverpod `Ref` or `BuildContext` to model constructors.
- Do not add network or I/O calls inside `Model`, `PartialModel`, or `EventBase`.
- Prefer extending existing abstractions (`RegularModel`, `ReplaceableModel`, etc.) over introducing new base classes.
- Code must be structured for human review first, not for AI generation convenience.

## Anti-Patterns

- **Silent query hang** — a `Future` that never completes because a relay never sends EOSE.
- **Mutable `ImmutableEvent`** — casting away `final` or using `metadata` to store mutable state that changes after construction.
- **Unregistered kind access** — querying a kind before `Model.register` has been called (throws at runtime; catch it in tests).
- **`part`/`part of`** — all new files use standard `import`/`export`.
- **Caching empty results** — relationship caches must not store empty lists; empty means "not yet arrived", not "definitely absent".
- **Production use of `DummySigner`** — it produces fake signatures that will be rejected by any real relay.

## Working With AI

- Spec-first for any behavior change to query lifecycle, flushing, or the storage contract.
- Work packets in `spec/work/` for non-trivial tasks.
- If a spec is unclear or incorrect, stop and report a Spec Issue — do not guess.
- Never modify `spec/guidelines/` without explicit permission.

## Knowledge Entries

After a work packet merges, promote non-obvious decisions to `spec/knowledge/DEC-XXX-*.md`. See `spec/knowledge/_TEMPLATE.md` for format and criteria.

### Task Completeness

For non-trivial work, changes are not complete unless:

- Work packet reflects the actual work performed
- No significant code exists outside the task plan
- Edge cases and failure modes are addressed (especially empty results and timeouts)

# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **`subscriptionPrefix` parameter for debugging**: The `Request` constructor, `Request.fromIds`, `RequestFilter.toRequest()`, and `storage.query()` now accept an optional `subscriptionPrefix` parameter to make subscription IDs more readable for debugging.
  - Instead of generic IDs like `sub-123456`, you can use descriptive prefixes like `app-detail-123456` or `user-profile-123456`
  - Helps identify which part of your app created a subscription when inspecting relay traffic or logs
  - The prefix is automatically appended with a random number to ensure uniqueness
  - Example: `Request(filters, subscriptionPrefix: 'app-detail')` generates IDs like `app-detail-123456`
  - Purely for debugging convenience and doesn't affect functionality

- **`andSource` parameter for independent relationship source control**: The `query()`, `queryKinds()`, and `model()` functions now accept an optional `andSource` parameter that allows you to specify a different source configuration for relationship queries (via the `and` parameter).
  - Main queries and their relationships can now use different `stream`, `background`, relay groups, or even source types
  - Example: Main query can use `stream: false` while relationships use `stream: true`
  - Example: Main query can use `LocalSource()` while relationships fetch fresh data with `LocalAndRemoteSource()`
  - If `andSource` is not provided, relationships continue to inherit from the main `source` (backward compatible)

### Fixed
- **`stream: false` now properly waits for EOSE**: When using `stream: false` in query sources, the query now correctly waits for EOSE (End of Stored Events) before returning, regardless of the `background` flag setting. This ensures that `and` relationships are properly fetched for all models, not just those already in local storage.
  - Previously, `stream: false` with `background: true` would return immediately with only local results, causing relationship data to be missing
  - The `background` flag is now ignored when `stream: false`, as it doesn't make sense to return before fetching results in a one-time query
  - Updated documentation to clarify the behavior of `stream` and `background` parameters

- **Relationship queries now inherit `stream` parameter**: When fetching relationship data via `and`, the relationship queries now respect the `stream` parameter from the parent query.
  - Previously, relationship queries would always use `stream: true` regardless of the parent query's setting
  - Now if you query with `stream: false`, the related data (apps, authors, etc.) will also be fetched with `stream: false` (one-time fetch)
  - Relationship queries still use `background: true` to avoid blocking the main query

### Behavior Changes
- **Query Source Semantics**:
  - `stream: true, background: true` - Return immediately with local results, fetch remote in background, keep streaming
  - `stream: true, background: false` - Wait for EOSE, then keep streaming for new events
  - `stream: false` - Always wait for EOSE (one-time fetch), `background` flag is ignored

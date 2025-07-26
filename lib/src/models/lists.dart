part of models;

/// An app curation set event (kind 30267) for organizing applications.
///
/// App curation sets provide curated lists of applications,
/// similar to app stores or recommendation lists.
class AppCurationSet extends ParameterizableReplaceableModel<AppCurationSet> {
  AppCurationSet.fromMap(super.map, super.ref) : super.fromMap();
}

/// Generated partial model mixin for AppCurationSet
mixin PartialAppCurationSetMixin
    on ParameterizableReplaceablePartialModel<AppCurationSet> {
  // No event-based getters found in AppCurationSet
}

/// Create and sign new app curation set events.
class PartialAppCurationSet
    extends ParameterizableReplaceablePartialModel<AppCurationSet>
    with PartialAppCurationSetMixin {
  PartialAppCurationSet.fromMap(super.map) : super.fromMap();

  /// Creates a new app curation set
  PartialAppCurationSet();
}

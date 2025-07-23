part of models;

class AppCurationSet extends ParameterizableReplaceableModel<AppCurationSet> {
  AppCurationSet.fromMap(super.map, super.ref) : super.fromMap();
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for AppCurationSet
mixin PartialAppCurationSetMixin
    on ParameterizableReplaceablePartialModel<AppCurationSet> {
  // No event-based getters found in AppCurationSet
}

class PartialAppCurationSet
    extends ParameterizableReplaceablePartialModel<AppCurationSet>
    with PartialAppCurationSetMixin {
  PartialAppCurationSet.fromMap(super.map) : super.fromMap();
  PartialAppCurationSet();
}

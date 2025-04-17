part of models;

class AppCurationSet extends ParameterizableReplaceableModel<AppCurationSet> {
  AppCurationSet.fromMap(super.map, super.ref) : super.fromMap();
}

class PartialAppCurationSet
    extends ParameterizableReplaceablePartialEvent<AppCurationSet> {}

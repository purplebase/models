part of models;

@GeneratePartialModel()
class AppCurationSet extends ParameterizableReplaceableModel<AppCurationSet> {
  AppCurationSet.fromMap(super.map, super.ref) : super.fromMap();
}

class PartialAppCurationSet
    extends ParameterizableReplaceablePartialModel<AppCurationSet>
    with PartialAppCurationSetMixin {
  PartialAppCurationSet.fromMap(super.map) : super.fromMap();
  PartialAppCurationSet();
}

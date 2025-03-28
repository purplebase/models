import 'package:models/src/core/event.dart';

class AppCurationSet extends ParameterizableReplaceableEvent<AppCurationSet> {
  AppCurationSet.fromMap(super.map, super.ref) : super.fromMap();
}

class PartialAppCurationSet
    extends ParameterizableReplaceablePartialEvent<AppCurationSet> {}

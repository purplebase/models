import 'package:models/src/core/event.dart';
import 'package:models/src/core/utils.dart';

class AppCurationSet extends ParameterizableReplaceableEvent<AppCurationSet> {
  AppCurationSet.fromMap(super.map, super.ref) : super.fromMap();
  Set<String> get appIds => internal
      .getTagSetValues('a')
      .map((e) => e.toReplaceableLink())
      .toSet()
      .map((a) => a.$3)
      .nonNulls
      .toSet();
}

class PartialAppCurationSet
    extends ParameterizableReplaceablePartialEvent<AppCurationSet> {}

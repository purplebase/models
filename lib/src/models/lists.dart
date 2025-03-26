import 'package:models/src/core/event.dart';

class AppCurationSet = ParameterizableReplaceableEvent<AppCurationSet>
    with AppCurationSetMixin;

class PartialAppCurationSet = ParameterizableReplaceablePartialEvent<
    AppCurationSet> with AppCurationSetMixin, PartialAppCurationSetMixin;

mixin AppCurationSetMixin on EventBase<AppCurationSet> {
  Set<String> get appIds =>
      internal.linkedReplaceableEventIds.map((a) => a.$3).nonNulls.toSet();
}

mixin PartialAppCurationSetMixin on PartialEventBase<AppCurationSet> {}

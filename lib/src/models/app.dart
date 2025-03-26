import 'package:models/src/core/event.dart';

class App = ParameterizableReplaceableEvent<App> with AppMixin;
class PartialApp = ParameterizableReplaceablePartialEvent<App>
    with AppMixin, PartialAppMixin;

mixin AppMixin on EventBase<App> {
  String? get name => internal.getFirstTagValue('name');
  String? get repository => internal.getFirstTagValue('repository');
  String get description => internal.content;
  String? get url => internal.getFirstTagValue('url');
  String? get license => internal.getFirstTagValue('license');
  Set<String> get icons => internal.getTagSetValues('icon');
  Set<String> get images => internal.getTagSetValues('image');
}

mixin PartialAppMixin on PartialEventBase<App> {
  set description(String value) => internal.content = value;
  set name(String? value) => internal.setTagValue('name', value);
  set repository(String? value) => internal.setTagValue('repository', value);
  set url(String? value) => internal.setTagValue('url', value);
  void addIcon(String value) => internal.addTagValue('icon', value);
  void addImage(String value) => internal.addTagValue('image', value);
}

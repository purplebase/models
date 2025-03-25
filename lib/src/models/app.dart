import 'package:models/src/core/event.dart';

class App = ParameterizableReplaceableEvent<App> with AppMixin;
class PartialApp = ParameterizableReplaceablePartialEvent<App>
    with AppMixin, PartialAppMixin;

mixin AppMixin on EventBase<App> {
  String? get name => event.getTag('name');
  String? get repository => event.getTag('repository');
  String get description => event.content;
  String? get url => event.getTag('url');
  String? get license => event.getTag('license');
  Set<String> get icons => event.getTagSet('icon');
  Set<String> get images => event.getTagSet('image');
}

mixin PartialAppMixin on PartialEventBase<App> {
  set description(String value) => event.content = value;
  set name(String? value) => event.setTag('name', value);
  set repository(String? value) => event.setTag('repository', value);
  set url(String? value) => event.setTag('url', value);
  void addIcon(String value) => event.addTag('icon', value);
  void addImage(String value) => event.addTag('image', value);
}

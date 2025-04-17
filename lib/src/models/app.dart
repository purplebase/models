part of models;

class App extends ParameterizableReplaceableModel<App> {
  App.fromMap(super.map, super.ref) : super.fromMap();

  String? get name => event.getFirstTagValue('name');
  String? get repository => event.getFirstTagValue('repository');
  String get description => event.content;
  String? get url => event.getFirstTagValue('url');
  String? get license => event.getFirstTagValue('license');
  Set<String> get icons => event.getTagSetValues('icon');
  Set<String> get images => event.getTagSetValues('image');
}

class PartialApp extends ParameterizableReplaceablePartialEvent<App> {
  set description(String value) => event.content = value;
  set name(String? value) => event.setTagValue('name', value);
  set repository(String? value) => event.setTagValue('repository', value);
  set url(String? value) => event.setTagValue('url', value);
  void addIcon(String value) => event.addTagValue('icon', value);
  void addImage(String value) => event.addTagValue('image', value);
}

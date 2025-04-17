part of models;

class Release extends ParameterizableReplaceableModel<Release> {
  Release.fromMap(super.map, super.ref) : super.fromMap();

  String get releaseNotes => event.content;
  String get version => event.identifier.split('@').last;
}

class PartialRelease extends ParameterizableReplaceablePartialEvent<Release> {
  set releaseNotes(String value) => event.content = value;
}

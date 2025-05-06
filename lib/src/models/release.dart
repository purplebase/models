part of models;

class Release extends ParameterizableReplaceableModel<Release> {
  Release.fromMap(super.map, super.ref) : super.fromMap();

  String get releaseNotes => event.content;
  String get version => event.identifier.split('@').last;
}

class PartialRelease extends ParameterizableReplaceablePartialEvent<Release> {
  set url(String? value) => event.setTagValue('url', value);
  set releaseNotes(String value) => event.content = value;
  set version(String? value) => event.setTagValue('d',
      '${event.getFirstTagValue('d')!.split('@').firstOrNull ?? ''}@$value');
  String? get version => event.getFirstTagValue('d')?.split('@').last;
}

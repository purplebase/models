part of models;

class Release extends ParameterizableReplaceableModel<Release> {
  Release.fromMap(super.map, super.ref) : super.fromMap();

  String get releaseNotes => event.content;
  String get version => event.identifier.split('@').last;
}

class PartialRelease extends ParameterizableReplaceablePartialEvent<Release> {
  set url(String? value) => event.setTagValue('url', value);
  set releaseNotes(String value) => event.content = value;
  // TODO: set identifier() => event.tag('i')
  // This will allow us to deprecate the `a` to release in app (to find the latest)
  // as we can now do req{pubkey=app.pubkey,i=app.dTag,kind=30063}
  set version(String? value) => event.setTagValue('d',
      '${event.getFirstTagValue('d')!.split('@').firstOrNull ?? ''}@$value');
  String? get version => event.getFirstTagValue('d')?.split('@').last;
}

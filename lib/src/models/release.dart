part of models;

class Release extends ParameterizableReplaceableModel<Release> {
  late final BelongsTo<App> app;
  late final HasMany<FileMetadata> fileMetadatas;

  Release.fromMap(super.map, super.ref) : super.fromMap() {
    app = BelongsTo(
        ref, RequestFilter.fromReplaceable(event.getFirstTagValue('a')!));
    fileMetadatas =
        HasMany(ref, RequestFilter(ids: event.getTagSetValues('e').toSet()));
  }

  String? get releaseNotes => event.content.isEmpty ? null : event.content;
  String get appIdentifier => event.getFirstTagValue('i')!;
  String get version => event.identifier.split('@').last;
  String? get url => event.getFirstTagValue('url');
}

class PartialRelease extends ParameterizableReplaceablePartialEvent<Release> {
  String? get releaseNotes => event.content.isEmpty ? null : event.content;
  set url(String? value) => event.setTagValue('url', value);
  set releaseNotes(String? value) => event.content = value ?? '';

  set appIdentifier(String? value) => event.setTagValue('i', value);
  set version(String? value) => event.setTagValue('d',
      '${event.getFirstTagValue('d')!.split('@').firstOrNull ?? ''}@$value');
  String? get version => event.getFirstTagValue('d')?.split('@').last;
}

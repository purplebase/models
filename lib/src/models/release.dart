part of models;

@GeneratePartialModel()
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
  String? get url => event.getFirstTagValue('url');

  String get appIdentifier {
    // With fallback to legacy method
    return event.getFirstTagValue('i') ?? event.identifier.split('@').first;
  }

  String get version {
    // With fallback to legacy method
    return event.getFirstTagValue('version') ??
        event.identifier.split('@').last;
  }
}

class PartialRelease extends ParameterizableReplaceablePartialEvent<Release>
    with PartialReleaseMixin {}

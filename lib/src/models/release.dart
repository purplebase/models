part of models;

@GeneratePartialModel()
class Release extends ParameterizableReplaceableModel<Release> {
  late final BelongsTo<App> app;
  late final HasMany<FileMetadata> fileMetadatas;
  late final HasMany<SoftwareAsset> softwareAssets;

  Release.fromMap(super.map, super.ref) : super.fromMap() {
    app = BelongsTo(
        ref,
        event.containsTag('a')
            ? Request<App>.fromIds({event.getFirstTagValue('a')!})
            // New format
            : RequestFilter<App>(
                authors: {event.pubkey},
                tags: {
                  '#d': {event.identifier}
                },
                limit: 1,
              ).toRequest());
    fileMetadatas = HasMany(
        ref,
        RequestFilter<FileMetadata>(
            ids: event.getTagSetValues('e').toSet(),
            kinds: {1063}).toRequest());
    softwareAssets = HasMany(
        ref,
        RequestFilter<SoftwareAsset>(
            ids: event.getTagSetValues('e').toSet(),
            kinds: {3063}).toRequest());
  }

  String? get releaseNotes => event.content.isEmpty ? null : event.content;
  String? get url => event.getFirstTagValue('url');
  String? get channel => event.getFirstTagValue('c');

  @override
  String get identifier {
    return '$appIdentifier@$version';
  }

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
    with PartialReleaseMixin {
  final bool newFormat;
  PartialRelease({this.newFormat = false});

  @override
  String? get appIdentifier {
    if (!newFormat) {
      final value = event.identifier?.split('@').firstOrNull;
      if (value == null) return null;
      return value.isEmpty ? null : value;
    }
    return event.getFirstTagValue('i');
  }

  @override
  String? get version {
    if (!newFormat) {
      final value = event.identifier?.split('@').lastOrNull;
      if (value == null) return null;
      return value.isEmpty ? null : value;
    }
    return event.getFirstTagValue('version');
  }

  @override
  set appIdentifier(String? value) {
    if (!newFormat) {
      throw UnimplementedError('Use identifier setter');
    }
    event.setTagValue('i', value);
  }

  @override
  set version(String? value) {
    if (!newFormat) {
      throw UnimplementedError('Use identifier setter');
    }
    event.setTagValue('version', value);
  }
}

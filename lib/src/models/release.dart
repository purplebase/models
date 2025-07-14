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
  String? get url =>
      event.getFirstTagValue('url') ?? event.getFirstTagValue('r');
  String? get channel => event.getFirstTagValue('c');

  @override
  String get identifier {
    return '$appIdentifier@$version';
  }

  String get appIdentifier {
    // With fallback to legacy method
    return event.getFirstTagValue('i') ??
        _getNullableSplit(event.identifier).$1!;
  }

  String get version {
    // With fallback to legacy method
    return event.getFirstTagValue('version') ??
        _getNullableSplit(event.identifier).$2!;
  }
}

class PartialRelease extends ParameterizableReplaceablePartialEvent<Release>
    with PartialReleaseMixin {
  final bool newFormat;
  PartialRelease({this.newFormat = false});

  @override
  String? get appIdentifier {
    if (!newFormat) {
      final value = event.identifier != null
          ? _getNullableSplit(event.identifier!).$1
          : null;
      if (value == null) return null;
      return value.isEmpty ? null : value;
    }
    return event.getFirstTagValue('i');
  }

  @override
  String? get version {
    if (!newFormat) {
      final value = event.identifier != null
          ? _getNullableSplit(event.identifier!).$2
          : null;
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

  @override
  set url(String? value) {
    if (newFormat) {
      event.setTagValue('r', value);
    } else {
      event.setTagValue('url', value);
    }
  }
}

(String? identifier, String? version) _getNullableSplit(String str) {
  final r = str.split('@');
  String? identifier;
  String? version;
  if (r.length > 1) {
    identifier = r.first.isNotEmpty ? r.first : null;
    version = r.last.isNotEmpty ? r.last : null;
  }
  return (identifier, version);
}

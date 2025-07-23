part of models;

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
                '#d': {event.identifier},
              },
              limit: 1,
            ).toRequest(),
    );
    fileMetadatas = HasMany(
      ref,
      RequestFilter<FileMetadata>(
        ids: event.getTagSetValues('e').toSet(),
        kinds: {1063},
      ).toRequest(),
    );
    softwareAssets = HasMany(
      ref,
      RequestFilter<SoftwareAsset>(
        ids: event.getTagSetValues('e').toSet(),
        kinds: {3063},
      ).toRequest(),
    );
  }

  String? get releaseNotes => event.content.isEmpty ? null : event.content;
  String? get url =>
      event.getFirstTagValue('url') ?? event.getFirstTagValue('r');
  String? get channel => event.getFirstTagValue('c');
  String? get commitId => event.getFirstTagValue('commit');

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

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for Release
mixin PartialReleaseMixin on ParameterizableReplaceablePartialModel<Release> {
  String? get releaseNotes => event.content.isEmpty ? null : event.content;
  set releaseNotes(String? value) => event.content = value ?? '';
  String? get url => event.getFirstTagValue('url');
  set url(String? value) => event.setTagValue('url', value);
  String? get channel => event.getFirstTagValue('c');
  set channel(String? value) => event.setTagValue('c', value);
  String? get commitId => event.getFirstTagValue('commit');
  set commitId(String? value) => event.setTagValue('commit', value);
  String? get appIdentifier => event.getFirstTagValue('i');
  set appIdentifier(String? value) => event.setTagValue('i', value);
  String? get version => event.getFirstTagValue('version');
  set version(String? value) => event.setTagValue('version', value);
}

class PartialRelease extends ParameterizableReplaceablePartialModel<Release>
    with PartialReleaseMixin {
  PartialRelease.fromMap(super.map) : newFormat = false, super.fromMap();

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

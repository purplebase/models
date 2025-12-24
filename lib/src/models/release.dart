part of models;

/// A software release event (kind 30063) representing a version of an application.
///
/// Releases contain version information, download links, and associated files
/// for a specific version of a software application. They link to apps and
/// can include file metadata and software assets.
class Release extends ParameterizableReplaceableModel<Release> {
  late final BelongsTo<App> app;
  late final HasMany<FileMetadata> fileMetadatas;
  late final BelongsTo<FileMetadata> latestMetadata;
  late final HasMany<SoftwareAsset> softwareAssets;
  late final BelongsTo<SoftwareAsset> latestAsset;

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
      ).toRequest(),
    );
    latestMetadata = BelongsTo(
      ref,
      RequestFilter<FileMetadata>(
        ids: {?event.getFirstTagValue('e')},
        limit: 1,
      ).toRequest(),
    );
    softwareAssets = HasMany(
      ref,
      RequestFilter<SoftwareAsset>(
        ids: event.getTagSetValues('e').toSet(),
      ).toRequest(),
    );
    latestAsset = BelongsTo(
      ref,
      RequestFilter<SoftwareAsset>(
        ids: {?event.getFirstTagValue('e')},
        limit: 1,
      ).toRequest(),
    );
  }

  /// Release notes content describing changes and features
  String? get releaseNotes => event.content.isEmpty ? null : event.content;

  /// Download URL for the release
  String? get url => event.getFirstTagValue('url');

  /// Title of the release, if any
  String? get title => event.getFirstTagValue('title');

  /// Release channel (e.g., 'stable', 'beta', 'alpha')
  String? get channel => event.getFirstTagValue('c');

  /// Git commit identifier for this release
  String? get commitId => event.getFirstTagValue('commit');

  @override
  /// Combined identifier in format 'appId@version'
  String get identifier {
    return '$appIdentifier@$version';
  }

  /// The parent application identifier
  String get appIdentifier {
    // With fallback to legacy method
    return event.getFirstTagValue('i') ??
        _getNullableSplit(event.identifier).$1!;
  }

  /// The version string for this release
  String get version {
    // With fallback to legacy method
    return event.getFirstTagValue('version') ??
        _getNullableSplit(event.identifier).$2!;
  }
}

/// Generated partial model mixin for Release
mixin PartialReleaseMixin on ParameterizableReplaceablePartialModel<Release> {
  /// Release notes content
  String? get releaseNotes => event.content.isEmpty ? null : event.content;

  /// Sets the release notes content
  set releaseNotes(String? value) => event.content = value ?? '';

  /// Download URL for the release
  String? get url => event.getFirstTagValue('url');

  /// Sets the download URL
  set url(String? value) => event.setTagValue('url', value);

  /// Title of the release
  String? get title => event.getFirstTagValue('title');

  /// Sets the release title
  set title(String? value) => event.setTagValue('title', value);

  /// Release channel
  String? get channel => event.getFirstTagValue('c');

  /// Sets the release channel
  set channel(String? value) => event.setTagValue('c', value);

  /// Git commit identifier
  String? get commitId => event.getFirstTagValue('commit');

  /// Sets the commit identifier
  set commitId(String? value) => event.setTagValue('commit', value);

  /// The parent application identifier
  String? get appIdentifier => event.getFirstTagValue('i');

  /// Sets the application identifier
  set appIdentifier(String? value) => event.setTagValue('i', value);

  /// The version string
  String? get version => event.getFirstTagValue('version');

  /// Sets the version string
  set version(String? value) => event.setTagValue('version', value);
}

/// Create and sign new release events.
///
/// Example usage:
/// ```dart
/// final release = await PartialRelease().signWith(signer);
/// ```
class PartialRelease extends ParameterizableReplaceablePartialModel<Release>
    with PartialReleaseMixin {
  PartialRelease.fromMap(super.map) : newFormat = false, super.fromMap();

  final bool newFormat;

  /// Creates a new release event
  ///
  /// [newFormat] - Whether to use the new tag-based format instead of legacy format
  PartialRelease({this.newFormat = false});

  @override
  String? get appIdentifier {
    if (!newFormat) {
      // Legacy
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
  set url(String? value) => event.setTagValue('url', value);
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

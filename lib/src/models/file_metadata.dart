part of models;

/// A file metadata event (kind 1063) containing information about a file.
///
/// File metadata events describe files with details like hash, size, MIME type,
/// and download URLs. They're used for software distribution and file sharing.
class FileMetadata extends RegularModel<FileMetadata> {
  late final BelongsTo<Release> release;

  FileMetadata.fromMap(super.map, super.ref) : super.fromMap() {
    release = BelongsTo(
      ref,
      RequestFilter<Release>(
        authors: {event.pubkey},
        tags: {
          '#e': {event.id},
        },
        limit: 1,
      ).toRequest(),
    );
  }

  /// Set of download URLs for the file
  Set<String> get urls => event.getTagSetValues('url').toSet();

  /// MIME type of the file
  String? get mimeType => event.getFirstTagValue('m');

  /// File hash for verification (SHA-256 or other)
  String get hash => event.getFirstTagValue('x')!;

  /// File size in bytes
  int? get size => event.getFirstTagValue('size').toInt();

  /// Source repository URL
  String? get repository => event.getFirstTagValue('repository');

  /// Set of supported platforms
  Set<String> get platforms => event.getTagSetValues('f').toSet();

  /// Set of executable file names within the file
  Set<String> get executables => event.getTagSetValues('executable');

  /// Minimum SDK version required
  String get minSdkVersion => event.getFirstTagValue('min_sdk_version')!;

  /// Target SDK version
  String get targetSdkVersion => event.getFirstTagValue('target_sdk_version')!;

  /// Parent application identifier
  String get appIdentifier =>
      event.getFirstTagValue('i') ?? _getNullableSplit(event.content).$1!;

  /// Version string for this file
  String get version => event.getFirstTagValue('version')!;

  // Android-specific properties

  /// Android version code (numeric)
  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');

  /// APK signature hash for Android apps
  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');
}

/// Generated partial model mixin for FileMetadata
mixin PartialFileMetadataMixin on RegularPartialModel<FileMetadata> {
  /// Set of download URLs for the file
  Set<String> get urls => event.getTagSetValues('url');

  /// Sets the download URLs
  set urls(Set<String> value) => event.setTagValues('url', value);

  /// Adds a download URL
  void addUrl(String? value) => event.addTagValue('url', value);

  /// Removes a download URL
  void removeUrl(String? value) => event.removeTagWithValue('url', value);

  /// MIME type of the file
  String? get mimeType => event.getFirstTagValue('m');

  /// Sets the MIME type
  set mimeType(String? value) => event.setTagValue('m', value);

  /// File hash for verification
  String? get hash => event.getFirstTagValue('x');

  /// Sets the file hash
  set hash(String? value) => event.setTagValue('x', value);

  /// File size in bytes
  int? get size => int.tryParse(event.getFirstTagValue('size') ?? '');

  /// Sets the file size
  set size(int? value) => event.setTagValue('size', value?.toString());

  /// Source repository URL
  String? get repository => event.getFirstTagValue('repository');

  /// Sets the repository URL
  set repository(String? value) => event.setTagValue('repository', value);

  /// Set of supported platforms
  Set<String> get platforms => event.getTagSetValues('f');

  /// Sets the supported platforms
  set platforms(Set<String> value) => event.setTagValues('f', value);

  /// Adds a supported platform
  void addPlatform(String? value) => event.addTagValue('f', value);

  /// Removes a supported platform
  void removePlatform(String? value) => event.removeTagWithValue('f', value);

  /// Set of executable file names
  Set<String> get executables => event.getTagSetValues('executable');

  /// Sets the executable file names
  set executables(Set<String> value) => event.setTagValues('executable', value);

  /// Adds an executable file name
  void addExecutable(String? value) => event.addTagValue('executable', value);

  /// Removes an executable file name
  void removeExecutable(String? value) =>
      event.removeTagWithValue('executable', value);

  /// Minimum SDK version required
  String? get minSdkVersion => event.getFirstTagValue('min_sdk_version');

  /// Sets the minimum SDK version
  set minSdkVersion(String? value) =>
      event.setTagValue('min_sdk_version', value);

  /// Target SDK version
  String? get targetSdkVersion => event.getFirstTagValue('target_sdk_version');

  /// Sets the target SDK version
  set targetSdkVersion(String? value) =>
      event.setTagValue('target_sdk_version', value);

  /// Parent application identifier
  String? get appIdentifier => event.getFirstTagValue('i');

  /// Sets the application identifier
  set appIdentifier(String? value) => event.setTagValue('i', value);

  /// Version string
  String? get version => event.getFirstTagValue('version');

  /// Sets the version string
  set version(String? value) => event.setTagValue('version', value);

  /// Android version code
  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');

  /// Sets the Android version code
  set versionCode(int? value) =>
      event.setTagValue('version_code', value?.toString());

  /// APK signature hash
  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');

  /// Sets the APK signature hash
  set apkSignatureHash(String? value) =>
      event.setTagValue('apk_signature_hash', value);
}

/// Create and sign new file metadata events.
class PartialFileMetadata extends RegularPartialModel<FileMetadata>
    with PartialFileMetadataMixin {
  PartialFileMetadata.fromMap(super.map) : super.fromMap();

  /// Creates a new file metadata event
  PartialFileMetadata();

  @override
  String? get appIdentifier => _getNullableSplit(event.content).$1;

  @override
  set appIdentifier(String? value) {
    if (version == null) {
      throw UnsupportedError('You must first set version');
    }
    event.content = '${value ?? ''}@$version';
  }
}

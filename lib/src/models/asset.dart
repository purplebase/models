part of models;

/// A software asset event (kind 3063) containing downloadable software files.
///
/// Software assets represent files that can be downloaded and installed,
/// including platform-specific information, version details, and checksums.
class SoftwareAsset extends RegularModel<SoftwareAsset> {
  SoftwareAsset.fromMap(super.map, super.ref) : super.fromMap();

  /// Set of download URLs for the software asset
  Set<String> get urls => event.getTagSetValues('url').toSet();

  /// MIME type of the software asset file
  String? get mimeType => event.getFirstTagValue('m');

  /// File hash for verification (SHA-256 or other)
  String get hash => event.getFirstTagValue('x')!;

  /// File size in bytes
  int? get size => event.getFirstTagValue('size').toInt();

  /// Source repository URL
  String? get repository => event.getFirstTagValue('repository');

  /// Set of supported platforms
  Set<String> get platforms => event.getTagSetValues('f').toSet();

  /// Set of executable file names within the asset
  Set<String> get executables => event.getTagSetValues('executable');

  /// Minimum OS version required to run the software
  String get minOSVersion => event.getFirstTagValue('min_os_version')!;

  /// Target OS version for optimal performance
  String get targetOSVersion => event.getFirstTagValue('target_os_version')!;

  /// Application identifier this asset belongs to
  String get appIdentifier => event.getFirstTagValue('i')!;

  /// Version string of the software asset
  String get version => event.getFirstTagValue('version')!;

  /// Original filename of the asset
  String? get filename => event.getFirstTagValue('filename');

  /// Asset variant (e.g., 'debug', 'release', 'lite')
  String? get variant => event.getFirstTagValue('variant');

  // Android-specific properties

  /// Android version code (numeric)
  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');

  /// APK signature hash for Android applications
  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');
}

/// Generated partial model mixin for SoftwareAsset
mixin PartialSoftwareAssetMixin on RegularPartialModel<SoftwareAsset> {
  /// Set of download URLs for the software asset
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

  /// Minimum OS version required
  String? get minOSVersion => event.getFirstTagValue('min_os_version');

  /// Sets the minimum OS version
  set minOSVersion(String? value) => event.setTagValue('min_os_version', value);

  /// Target OS version
  String? get targetOSVersion => event.getFirstTagValue('target_os_version');

  /// Sets the target OS version
  set targetOSVersion(String? value) =>
      event.setTagValue('target_os_version', value);

  /// Application identifier
  String? get appIdentifier => event.getFirstTagValue('i');

  /// Sets the application identifier
  set appIdentifier(String? value) => event.setTagValue('i', value);

  /// Version string
  String? get version => event.getFirstTagValue('version');

  /// Sets the version string
  set version(String? value) => event.setTagValue('version', value);

  /// Original filename
  String? get filename => event.getFirstTagValue('filename');

  /// Sets the filename
  set filename(String? value) => event.setTagValue('filename', value);

  /// Asset variant
  String? get variant => event.getFirstTagValue('variant');

  /// Sets the asset variant
  set variant(String? value) => event.setTagValue('variant', value);

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

/// Create and sign new software asset events.
class PartialSoftwareAsset extends RegularPartialModel<SoftwareAsset>
    with PartialSoftwareAssetMixin {
  PartialSoftwareAsset.fromMap(super.map) : super.fromMap();

  /// Creates a new software asset event
  PartialSoftwareAsset();
}

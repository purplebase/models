part of models;

/// A software asset event (kind 3063) containing downloadable software files.
///
/// Software assets represent files that can be downloaded and installed,
/// including platform-specific information, version details, and checksums.
///
/// Extends [FileMetadata] to inherit file metadata properties.
class SoftwareAsset extends FileMetadata {
  SoftwareAsset.fromMap(super.map, super.ref) : super.fromMap();

  /// Minimum platform version required to run the software
  String? get minPlatformVersion =>
      event.getFirstTagValue('min_platform_version');

  /// Target platform version for optimal performance
  String? get targetPlatformVersion =>
      event.getFirstTagValue('target_platform_version');

  /// Original filename of the asset
  String? get filename => event.getFirstTagValue('filename');

  /// Asset variant (e.g., 'debug', 'release', 'lite')
  String? get variant => event.getFirstTagValue('variant');

  /// Supported Nostr NIPs
  Set<String> get supportedNips => event.getTagSetValues('supported_nip');

  /// Platform-specific permissions required
  Set<String> get permissions => event.getTagSetValues('permission');

  /// APK certificate hashes for Android applications
  Set<String> get apkCertificateHashes =>
      event.getTagSetValues('apk_certificate_hash');
}

/// Generated partial model mixin for SoftwareAsset
mixin PartialSoftwareAssetMixin on PartialFileMetadata {
  /// Minimum platform version required
  String? get minPlatformVersion =>
      event.getFirstTagValue('min_platform_version');

  /// Sets the minimum platform version
  set minPlatformVersion(String? value) =>
      event.setTagValue('min_platform_version', value);

  /// Target platform version
  String? get targetPlatformVersion =>
      event.getFirstTagValue('target_platform_version');

  /// Sets the target platform version
  set targetPlatformVersion(String? value) =>
      event.setTagValue('target_platform_version', value);

  /// Original filename
  String? get filename => event.getFirstTagValue('filename');

  /// Sets the filename
  set filename(String? value) => event.setTagValue('filename', value);

  /// Asset variant
  String? get variant => event.getFirstTagValue('variant');

  /// Sets the asset variant
  set variant(String? value) => event.setTagValue('variant', value);

  /// Supported Nostr NIPs
  Set<String> get supportedNips => event.getTagSetValues('supported_nip');

  /// Sets the supported NIPs
  set supportedNips(Set<String> value) =>
      event.setTagValues('supported_nip', value);

  /// Adds a supported NIP
  void addSupportedNip(String? value) =>
      event.addTagValue('supported_nip', value);

  /// Removes a supported NIP
  void removeSupportedNip(String? value) =>
      event.removeTagWithValue('supported_nip', value);

  /// Platform-specific permissions
  Set<String> get permissions => event.getTagSetValues('permission');

  /// Sets platform-specific permissions
  set permissions(Set<String> value) => event.setTagValues('permission', value);

  /// Adds a platform-specific permission
  void addPermission(String? value) => event.addTagValue('permission', value);

  /// Removes a platform-specific permission
  void removePermission(String? value) =>
      event.removeTagWithValue('permission', value);

  /// APK certificate hashes
  Set<String> get apkCertificateHashes =>
      event.getTagSetValues('apk_certificate_hash');

  /// Sets the APK certificate hashes
  set apkCertificateHashes(Set<String> value) =>
      event.setTagValues('apk_certificate_hash', value);

  /// Adds an APK certificate hash
  void addApkCertificateHash(String? value) =>
      event.addTagValue('apk_certificate_hash', value);

  /// Removes an APK certificate hash
  void removeApkCertificateHash(String? value) =>
      event.removeTagWithValue('apk_certificate_hash', value);
}

/// Create and sign new software asset events.
class PartialSoftwareAsset extends PartialFileMetadata
    with PartialSoftwareAssetMixin {
  PartialSoftwareAsset.fromMap(super.map) : super.fromMap();

  /// Creates a new software asset event
  PartialSoftwareAsset();
}

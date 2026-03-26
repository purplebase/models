
import '../core/model.dart';
import '../filter/request_filter.dart';
import '../relationship/relationship.dart';
import '../utils/extensions.dart';
import 'app.dart';
import 'installable.dart';
import 'release.dart';

/// A software asset event (kind 3063) containing downloadable software files.
///
/// Self-referential model (`RegularModel<SoftwareAsset>`) so it can be used
/// with typed `query<SoftwareAsset>()`. Shares the [Installable] interface
/// with [FileMetadata] for consumers that handle either format.
class SoftwareAsset extends RegularModel<SoftwareAsset> implements Installable {
  late final BelongsTo<App> app;
  late final BelongsTo<Release> release;

  SoftwareAsset.fromMap(super.map, super.ref) : super.fromMap() {
    app = BelongsTo(
      ref,
      RequestFilter<App>(
        authors: {event.pubkey},
        tags: {
          '#d': {appIdentifier},
        },
        limit: 1,
      ).toRequest(),
    );
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

  // ── FileMetadata-equivalent getters ──────────────────────────────────

  Set<String> get urls => event.getTagSetValues('url').toSet();

  String? get mimeType => event.getFirstTagValue('m');

  String get hash => event.getFirstTagValue('x')!;

  int? get size => event.getFirstTagValue('size').toInt();

  String? get repository => event.getFirstTagValue('repository');

  Set<String> get platforms => event.getTagSetValues('f').toSet();

  Set<String> get executables => event.getTagSetValues('executable');

  String get minSdkVersion => event.getFirstTagValue('min_sdk_version')!;

  String get targetSdkVersion => event.getFirstTagValue('target_sdk_version')!;

  String get appIdentifier =>
      event.getFirstTagValue('i') ?? getNullableSplit(event.content).$1!;

  String get version => event.getFirstTagValue('version')!;

  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');

  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');

  // ── SoftwareAsset-specific getters ───────────────────────────────────

  String? get minPlatformVersion =>
      event.getFirstTagValue('min_platform_version');

  String? get targetPlatformVersion =>
      event.getFirstTagValue('target_platform_version');

  String? get filename => event.getFirstTagValue('filename');

  String? get variant => event.getFirstTagValue('variant');

  Set<String> get supportedNips => event.getTagSetValues('supported_nip');

  Set<String> get permissions => event.getTagSetValues('permission');

  Set<String> get apkCertificateHashes =>
      event.getTagSetValues('apk_certificate_hash');
}

/// Create and sign new software asset events.
class PartialSoftwareAsset extends RegularPartialModel<SoftwareAsset> {
  PartialSoftwareAsset.fromMap(super.map) : super.fromMap();

  PartialSoftwareAsset();

  // ── FileMetadata-equivalent partial fields ───────────────────────────

  Set<String> get urls => event.getTagSetValues('url');
  set urls(Set<String> value) => event.setTagValues('url', value);
  void addUrl(String? value) => event.addTagValue('url', value);
  void removeUrl(String? value) => event.removeTagWithValue('url', value);

  String? get mimeType => event.getFirstTagValue('m');
  set mimeType(String? value) => event.setTagValue('m', value);

  String? get hash => event.getFirstTagValue('x');
  set hash(String? value) => event.setTagValue('x', value);

  int? get size => int.tryParse(event.getFirstTagValue('size') ?? '');
  set size(int? value) => event.setTagValue('size', value?.toString());

  String? get repository => event.getFirstTagValue('repository');
  set repository(String? value) => event.setTagValue('repository', value);

  Set<String> get platforms => event.getTagSetValues('f');
  set platforms(Set<String> value) => event.setTagValues('f', value);
  void addPlatform(String? value) => event.addTagValue('f', value);
  void removePlatform(String? value) => event.removeTagWithValue('f', value);

  Set<String> get executables => event.getTagSetValues('executable');
  set executables(Set<String> value) => event.setTagValues('executable', value);
  void addExecutable(String? value) => event.addTagValue('executable', value);
  void removeExecutable(String? value) =>
      event.removeTagWithValue('executable', value);

  String? get minSdkVersion => event.getFirstTagValue('min_sdk_version');
  set minSdkVersion(String? value) =>
      event.setTagValue('min_sdk_version', value);

  String? get targetSdkVersion => event.getFirstTagValue('target_sdk_version');
  set targetSdkVersion(String? value) =>
      event.setTagValue('target_sdk_version', value);

  String? get appIdentifier => event.getFirstTagValue('i');
  set appIdentifier(String? value) => event.setTagValue('i', value);

  String? get version => event.getFirstTagValue('version');
  set version(String? value) => event.setTagValue('version', value);

  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');
  set versionCode(int? value) =>
      event.setTagValue('version_code', value?.toString());

  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');
  set apkSignatureHash(String? value) =>
      event.setTagValue('apk_signature_hash', value);

  // ── SoftwareAsset-specific partial fields ────────────────────────────

  String? get minPlatformVersion =>
      event.getFirstTagValue('min_platform_version');
  set minPlatformVersion(String? value) =>
      event.setTagValue('min_platform_version', value);

  String? get targetPlatformVersion =>
      event.getFirstTagValue('target_platform_version');
  set targetPlatformVersion(String? value) =>
      event.setTagValue('target_platform_version', value);

  String? get filename => event.getFirstTagValue('filename');
  set filename(String? value) => event.setTagValue('filename', value);

  String? get variant => event.getFirstTagValue('variant');
  set variant(String? value) => event.setTagValue('variant', value);

  Set<String> get supportedNips => event.getTagSetValues('supported_nip');
  set supportedNips(Set<String> value) =>
      event.setTagValues('supported_nip', value);
  void addSupportedNip(String? value) =>
      event.addTagValue('supported_nip', value);
  void removeSupportedNip(String? value) =>
      event.removeTagWithValue('supported_nip', value);

  Set<String> get permissions => event.getTagSetValues('permission');
  set permissions(Set<String> value) => event.setTagValues('permission', value);
  void addPermission(String? value) => event.addTagValue('permission', value);
  void removePermission(String? value) =>
      event.removeTagWithValue('permission', value);

  Set<String> get apkCertificateHashes =>
      event.getTagSetValues('apk_certificate_hash');
  set apkCertificateHashes(Set<String> value) =>
      event.setTagValues('apk_certificate_hash', value);
  void addApkCertificateHash(String? value) =>
      event.addTagValue('apk_certificate_hash', value);
  void removeApkCertificateHash(String? value) =>
      event.removeTagWithValue('apk_certificate_hash', value);
}

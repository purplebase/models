part of models;

class SoftwareAsset extends RegularModel<SoftwareAsset> {
  SoftwareAsset.fromMap(super.map, super.ref) : super.fromMap();

  Set<String> get urls => event.getTagSetValues('url').toSet();
  String? get mimeType => event.getFirstTagValue('m');
  String get hash => event.getFirstTagValue('x')!;
  int? get size => event.getFirstTagValue('size').toInt();

  String? get repository => event.getFirstTagValue('repository');
  Set<String> get platforms => event.getTagSetValues('f').toSet();
  Set<String> get executables => event.getTagSetValues('executable');

  String get minOSVersion => event.getFirstTagValue('min_os_version')!;
  String get targetOSVersion => event.getFirstTagValue('target_os_version')!;

  String get appIdentifier => event.getFirstTagValue('i')!;
  String get version => event.getFirstTagValue('version')!;

  String? get filename => event.getFirstTagValue('filename');
  String? get variant => event.getFirstTagValue('variant');

  // Android-specific
  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');
  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for SoftwareAsset
mixin PartialSoftwareAssetMixin on RegularPartialModel<SoftwareAsset> {
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
  String? get minOSVersion => event.getFirstTagValue('min_os_version');
  set minOSVersion(String? value) => event.setTagValue('min_os_version', value);
  String? get targetOSVersion => event.getFirstTagValue('target_os_version');
  set targetOSVersion(String? value) =>
      event.setTagValue('target_os_version', value);
  String? get appIdentifier => event.getFirstTagValue('i');
  set appIdentifier(String? value) => event.setTagValue('i', value);
  String? get version => event.getFirstTagValue('version');
  set version(String? value) => event.setTagValue('version', value);
  String? get filename => event.getFirstTagValue('filename');
  set filename(String? value) => event.setTagValue('filename', value);
  String? get variant => event.getFirstTagValue('variant');
  set variant(String? value) => event.setTagValue('variant', value);
  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');
  set versionCode(int? value) =>
      event.setTagValue('version_code', value?.toString());
  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');
  set apkSignatureHash(String? value) =>
      event.setTagValue('apk_signature_hash', value);
}

class PartialSoftwareAsset extends RegularPartialModel<SoftwareAsset>
    with PartialSoftwareAssetMixin {
  PartialSoftwareAsset.fromMap(super.map) : super.fromMap();
  PartialSoftwareAsset();
}

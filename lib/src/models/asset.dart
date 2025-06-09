part of models;

@GeneratePartialModel()
class SoftwareAsset extends RegularModel<SoftwareAsset> {
  // TODO: Should subclass FileMetadata?
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

class PartialSoftwareAsset extends RegularPartialModel<SoftwareAsset>
    with PartialSoftwareAssetMixin {}

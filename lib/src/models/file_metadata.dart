part of models;

class FileMetadata extends RegularModel<FileMetadata> {
  FileMetadata.fromMap(super.map, super.ref) : super.fromMap();
  Set<String> get urls => event.getTagSetValues('url').toSet();
  String? get mimeType => event.getFirstTagValue('m');
  String? get hash => event.getFirstTagValue('x');
  int? get size => event.getFirstTagValue('size').toInt();
  String? get version => event.getFirstTagValue('version');
  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');
  String? get repository => event.getFirstTagValue('repository');
  Set<String> get platforms => event.getTagSetValues('f').toSet();
  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');
  Set<String> get executables => event.getTagSetValues('executable');
}

class PartialFileMetadata extends RegularPartialModel<FileMetadata> {
  set url(String? value) => event.setTagValue('url', value);
  set versionCode(String? value) => event.setTagValue('version_code', value);
  set minSdkVersion(String? value) =>
      event.setTagValue('min_sdk_version', value);
  set targetSdkVersion(String? value) =>
      event.setTagValue('target_sdk_version', value);
  set mimeType(String? value) => event.setTagValue('m', value);
  set hash(String? value) => event.setTagValue('x', value);
  set size(int value) => event.setTagValue('size', value.toString());
  set identifier(String? value) => event.setTagValue('i', value);
  set version(String? value) => event.setTagValue('version', value);

  set platforms(Set<String> value) => event.setTagValues('f', value);
  set apkSignatureHashes(Set<String> value) =>
      event.setTagValues('apk_signature_hash', value);

  Set<String> get urls => event.getTagSetValues('url').toSet();
  Set<String> get platforms => event.getTagSetValues('f').toSet();
  Set<String> get apkSignatureHashes =>
      event.getTagSetValues('apk_signature_hash');

  String? get identifier {
    final i = event.getFirstTagValue('i');
    if (i != null) {
      return i;
    }
    final iv = event.content.split('@');
    if (iv.firstOrNull?.isNotEmpty ?? false) {
      return iv.first;
    }
    return null;
  }

  String? get version =>
      event.getFirstTagValue('version') ?? event.content.split('@').lastOrNull;
  String? get mimeType => event.getFirstTagValue('m');
}

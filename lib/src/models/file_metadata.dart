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
}

class PartialFileMetadata extends RegularPartialModel<FileMetadata> {}

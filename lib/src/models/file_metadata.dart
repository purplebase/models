part of models;

@GeneratePartialModel()
class FileMetadata extends RegularModel<FileMetadata> {
  FileMetadata.fromMap(super.map, super.ref) : super.fromMap();

  Set<String> get urls => event.getTagSetValues('url').toSet();
  String? get mimeType => event.getFirstTagValue('m');
  String get hash => event.getFirstTagValue('x')!;
  int? get size => event.getFirstTagValue('size').toInt();

  // TODO: Remove all fields below when switching to kind 3063 and make it subclass this
  String? get repository => event.getFirstTagValue('repository');
  Set<String> get platforms => event.getTagSetValues('f').toSet();
  Set<String> get executables => event.getTagSetValues('executable');

  String get minSdkVersion => event.getFirstTagValue('min_sdk_version')!;
  String get targetSdkVersion => event.getFirstTagValue('target_sdk_version')!;

  String get appIdentifier => event.content.split('@').first;
  String get version => event.content.split('@').last;

  // Android-specific
  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');
  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');
}

class PartialFileMetadata extends RegularPartialModel<FileMetadata>
    with PartialFileMetadataMixin {
  @override
  String? get appIdentifier => event.content.split('@').firstOrNull;
  @override
  String? get version => event.content.split('@').lastOrNull;

  @override
  set appIdentifier(String? value) {
    event.content = '$value@$version';
  }

  @override
  set version(String? value) {
    event.content = '$appIdentifier@$value';
  }
}

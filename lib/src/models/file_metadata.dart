part of models;

@GeneratePartialModel()
class FileMetadata extends RegularModel<FileMetadata> {
  FileMetadata.fromMap(super.map, super.ref) : super.fromMap();

  Set<String> get urls => event.getTagSetValues('url').toSet();
  String? get mimeType => event.getFirstTagValue('m');
  String get hash => event.getFirstTagValue('x')!;
  int? get size => event.getFirstTagValue('size').toInt();

  String? get repository => event.getFirstTagValue('repository');
  Set<String> get platforms => event.getTagSetValues('f').toSet();
  Set<String> get executables => event.getTagSetValues('executable');

  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');
  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');
  String get minSdkVersion => event.getFirstTagValue('min_sdk_version')!;
  String get targetSdkVersion => event.getFirstTagValue('target_sdk_version')!;

  String get identifier {
    // With fallback to legacy method
    return event.getFirstTagValue('i') ?? event.content.split('@').first;
  }

  String get version {
    // With fallback to legacy method
    return event.getFirstTagValue('version') ?? event.content.split('@').last;
  }
}

class PartialFileMetadata extends RegularPartialModel<FileMetadata>
    with PartialFileMetadataMixin {
  @override
  String? get identifier {
    // With fallback to legacy method
    return event.getFirstTagValue('i') ?? event.content.split('@').firstOrNull;
  }

  @override
  String? get version {
    // With fallback to legacy method
    return event.getFirstTagValue('version') ??
        event.content.split('@').lastOrNull;
  }
}

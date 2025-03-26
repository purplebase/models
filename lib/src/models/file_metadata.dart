import 'package:models/src/core/event.dart';
import 'package:models/src/core/utils.dart';

class FileMetadata = RegularEvent<FileMetadata> with FileMetadataMixin;

class PartialFileMetadata = RegularPartialEvent<FileMetadata>
    with FileMetadataMixin, PartialFileMetadataMixin;

mixin FileMetadataMixin on EventBase<FileMetadata> {
  Set<String> get urls => event.getTagSet('url');
  String? get mimeType => event.getFirstTagValue('m');
  String? get hash => event.getFirstTagValue('x');
  int? get size => event.getFirstTagValue('size').toInt();
  String? get version => event.getFirstTagValue('version');
  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');
  String? get repository => event.getFirstTagValue('repository');
  Set<String> get platforms => event.getTagSet('f');
  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');
}

mixin PartialFileMetadataMixin on PartialEventBase<FileMetadata> {}

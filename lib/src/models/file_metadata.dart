import 'package:models/src/core/event.dart';
import 'package:models/src/core/utils.dart';

class FileMetadata = RegularEvent<FileMetadata> with FileMetadataMixin;

class PartialFileMetadata = RegularPartialEvent<FileMetadata>
    with FileMetadataMixin, PartialFileMetadataMixin;

mixin FileMetadataMixin on EventBase<FileMetadata> {
  Set<String> get urls => internal.getTagSet('url');
  String? get mimeType => internal.getFirstTagValue('m');
  String? get hash => internal.getFirstTagValue('x');
  int? get size => internal.getFirstTagValue('size').toInt();
  String? get version => internal.getFirstTagValue('version');
  int? get versionCode =>
      int.tryParse(internal.getFirstTagValue('version_code') ?? '');
  String? get repository => internal.getFirstTagValue('repository');
  Set<String> get platforms => internal.getTagSet('f');
  String? get apkSignatureHash =>
      internal.getFirstTagValue('apk_signature_hash');
}

mixin PartialFileMetadataMixin on PartialEventBase<FileMetadata> {}

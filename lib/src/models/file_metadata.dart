import 'package:models/src/event.dart';
import 'package:models/src/utils.dart';

class FileMetadata = RegularEvent<FileMetadata> with FileMetadataMixin;

class PartialFileMetadata = RegularPartialEvent<FileMetadata>
    with FileMetadataMixin, PartialFileMetadataMixin;

mixin FileMetadataMixin on EventBase<FileMetadata> {
  Set<String> get urls => event.getTagSet('url');
  String? get mimeType => event.getTag('m');
  String? get hash => event.getTag('x');
  int? get size => event.getTag('size').toInt();
  String? get version => event.getTag('version');
  int? get versionCode => int.tryParse(event.getTag('version_code') ?? '');
  String? get repository => event.getTag('repository');
  Set<String> get platforms => event.getTagSet('f');
  String? get apkSignatureHash => event.getTag('apk_signature_hash');
}

mixin PartialFileMetadataMixin on PartialEventBase<FileMetadata> {}

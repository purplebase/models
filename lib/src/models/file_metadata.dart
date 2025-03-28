import 'package:models/src/core/event.dart';
import 'package:models/src/core/extensions.dart';

class FileMetadata extends RegularEvent<FileMetadata> {
  FileMetadata.fromMap(super.map, super.ref) : super.fromMap();
  Set<String> get urls => internal.getTagSetValues('url');
  String? get mimeType => internal.getFirstTagValue('m');
  String? get hash => internal.getFirstTagValue('x');
  int? get size => internal.getFirstTagValue('size').toInt();
  String? get version => internal.getFirstTagValue('version');
  int? get versionCode =>
      int.tryParse(internal.getFirstTagValue('version_code') ?? '');
  String? get repository => internal.getFirstTagValue('repository');
  Set<String> get platforms => internal.getTagSetValues('f');
  String? get apkSignatureHash =>
      internal.getFirstTagValue('apk_signature_hash');
}

class PartialFileMetadata extends RegularPartialEvent<FileMetadata> {}

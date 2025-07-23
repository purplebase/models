part of models;

class FileMetadata extends RegularModel<FileMetadata> {
  late final BelongsTo<Release> release;

  FileMetadata.fromMap(super.map, super.ref) : super.fromMap() {
    release = BelongsTo(
      ref,
      RequestFilter<Release>(
        authors: {event.pubkey},
        tags: {
          '#e': {event.id},
        },
        limit: 1,
      ).toRequest(),
    );
  }

  Set<String> get urls => event.getTagSetValues('url').toSet();
  String? get mimeType => event.getFirstTagValue('m');
  String get hash => event.getFirstTagValue('x')!;
  int? get size => event.getFirstTagValue('size').toInt();

  String? get repository => event.getFirstTagValue('repository');
  Set<String> get platforms => event.getTagSetValues('f').toSet();
  Set<String> get executables => event.getTagSetValues('executable');

  String get minSdkVersion => event.getFirstTagValue('min_sdk_version')!;
  String get targetSdkVersion => event.getFirstTagValue('target_sdk_version')!;

  String get appIdentifier =>
      event.getFirstTagValue('i') ?? _getNullableSplit(event.content).$1!;
  String get version => event.getFirstTagValue('version')!;

  // Android-specific
  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');
  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for FileMetadata
mixin PartialFileMetadataMixin on RegularPartialModel<FileMetadata> {
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
  String? get minSdkVersion => event.getFirstTagValue('min_sdk_version');
  set minSdkVersion(String? value) =>
      event.setTagValue('min_sdk_version', value);
  String? get targetSdkVersion => event.getFirstTagValue('target_sdk_version');
  set targetSdkVersion(String? value) =>
      event.setTagValue('target_sdk_version', value);
  String? get appIdentifier => event.getFirstTagValue('i');
  set appIdentifier(String? value) => event.setTagValue('i', value);
  String? get version => event.getFirstTagValue('version');
  set version(String? value) => event.setTagValue('version', value);
  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');
  set versionCode(int? value) =>
      event.setTagValue('version_code', value?.toString());
  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');
  set apkSignatureHash(String? value) =>
      event.setTagValue('apk_signature_hash', value);
}

class PartialFileMetadata extends RegularPartialModel<FileMetadata>
    with PartialFileMetadataMixin {
  PartialFileMetadata.fromMap(super.map) : super.fromMap();

  PartialFileMetadata();

  @override
  String? get appIdentifier => _getNullableSplit(event.content).$1;

  @override
  set appIdentifier(String? value) {
    if (version == null) {
      throw UnsupportedError('You must first set version');
    }
    event.content = '${value ?? ''}@$version';
  }
}

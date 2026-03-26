/// Shared interface for downloadable/installable file events.
///
/// Both FileMetadata (kind 1063) and SoftwareAsset (kind 3063) implement this,
/// allowing consumers to handle either format without type checks or casts.
abstract interface class Installable {
  String get id;
  Set<String> get urls;
  String? get mimeType;
  String get hash;
  int? get size;
  Set<String> get platforms;
  String get appIdentifier;
  String get version;
  int? get versionCode;
  String? get apkSignatureHash;
}

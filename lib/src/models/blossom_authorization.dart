part of models;

/// A blossom authorization event (kind 24242) for file server authentication.
///
/// Blossom authorization events provide authentication tokens for
/// uploading and managing files on Blossom file servers.
class BlossomAuthorization extends EphemeralModel<BlossomAuthorization> {
  BlossomAuthorization.fromMap(super.map, super.ref) : super.fromMap();

  /// Authorization content (token data)
  String get content => event.content;

  /// File hash being authorized for access
  String get hash => event.getFirstTagValue('x')!;

  /// MIME type of the file being authorized
  String? get mimeType => event.getFirstTagValue('m');

  /// Token expiration timestamp
  DateTime get expiration =>
      event.getFirstTagValue('expiration').toInt()!.toDate();

  /// Blossom server URL this authorization is valid for
  String get server => event.getFirstTagValue('server')!;

  /// Convert authorization to base64 format for HTTP headers
  String toBase64() {
    return base64Encode(utf8.encode(jsonEncode(toMap())));
  }
}

/// Generated partial model mixin for BlossomAuthorization
mixin PartialBlossomAuthorizationMixin
    on EphemeralPartialModel<BlossomAuthorization> {
  /// Authorization content (token data)
  String? get content => event.content.isEmpty ? null : event.content;

  /// Sets the authorization content
  set content(String? value) => event.content = value ?? '';

  /// File hash being authorized
  String? get hash => event.getFirstTagValue('x');

  /// Sets the file hash
  set hash(String? value) => event.setTagValue('x', value);

  /// MIME type of the file
  String? get mimeType => event.getFirstTagValue('m');

  /// Sets the MIME type
  set mimeType(String? value) => event.setTagValue('m', value);

  /// Token expiration timestamp
  DateTime? get expiration =>
      event.getFirstTagValue('expiration')?.toInt()?.toDate();

  /// Sets the expiration timestamp
  set expiration(DateTime? value) =>
      event.setTagValue('expiration', value?.toSeconds().toString());

  /// Blossom server URL
  String? get server => event.getFirstTagValue('server');

  /// Sets the server URL
  set server(String? value) => event.setTagValue('server', value);
}

/// Create and sign new blossom authorization events.
class PartialBlossomAuthorization
    extends EphemeralPartialModel<BlossomAuthorization>
    with PartialBlossomAuthorizationMixin {
  PartialBlossomAuthorization.fromMap(super.map) : super.fromMap();

  /// Creates a new blossom authorization event
  PartialBlossomAuthorization();

  /// Sets the authorization type
  set type(BlossomAuthorizationType value) =>
      event.setTagValue('t', value.name);
}

/// Types of blossom file operations that can be authorized
enum BlossomAuthorizationType {
  /// Get/download files
  get,

  /// Upload new files
  upload,

  /// List files
  list,

  /// Delete files
  delete,
}

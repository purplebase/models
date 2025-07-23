part of models;

class BlossomAuthorization extends EphemeralModel<BlossomAuthorization> {
  BlossomAuthorization.fromMap(super.map, super.ref) : super.fromMap();

  String get content => event.content;
  String get hash => event.getFirstTagValue('x')!;
  String? get mimeType => event.getFirstTagValue('m');
  DateTime get expiration =>
      event.getFirstTagValue('expiration').toInt()!.toDate();
  String get server => event.getFirstTagValue('server')!;

  String toBase64() {
    return base64Encode(utf8.encode(jsonEncode(toMap())));
  }
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for BlossomAuthorization
mixin PartialBlossomAuthorizationMixin
    on EphemeralPartialModel<BlossomAuthorization> {
  String? get content => event.content.isEmpty ? null : event.content;
  set content(String? value) => event.content = value ?? '';
  String? get hash => event.getFirstTagValue('x');
  set hash(String? value) => event.setTagValue('x', value);
  String? get mimeType => event.getFirstTagValue('m');
  set mimeType(String? value) => event.setTagValue('m', value);
  DateTime? get expiration =>
      event.getFirstTagValue('expiration')?.toInt()?.toDate();
  set expiration(DateTime? value) =>
      event.setTagValue('expiration', value?.toSeconds().toString());
  String? get server => event.getFirstTagValue('server');
  set server(String? value) => event.setTagValue('server', value);
}

class PartialBlossomAuthorization
    extends EphemeralPartialModel<BlossomAuthorization>
    with PartialBlossomAuthorizationMixin {
  PartialBlossomAuthorization.fromMap(super.map) : super.fromMap();
  PartialBlossomAuthorization();

  set type(BlossomAuthorizationType value) =>
      event.setTagValue('t', value.name);
}

enum BlossomAuthorizationType { get, upload, list, delete }

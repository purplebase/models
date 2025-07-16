part of models;

@GeneratePartialModel()
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

class PartialBlossomAuthorization
    extends EphemeralPartialModel<BlossomAuthorization>
    with PartialBlossomAuthorizationMixin {
  PartialBlossomAuthorization.fromMap(super.map) : super.fromMap();
  PartialBlossomAuthorization();

  set type(BlossomAuthorizationType value) =>
      event.setTagValue('t', value.name);
}

enum BlossomAuthorizationType { get, upload, list, delete }

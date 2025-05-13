part of models;

class BlossomAuthorization extends EphemeralModel<BlossomAuthorization> {
  BlossomAuthorization.fromMap(super.map, super.ref) : super.fromMap();

  String get content => event.content;
  Set<String> get hashes => event.getTagSetValues('x').toSet();
  String? get mimeType => event.getFirstTagValue('m');

  String toBase64() {
    return base64Encode(utf8.encode(jsonEncode(toMap())));
  }
}

class PartialBlossomAuthorization
    extends EphemeralPartialModel<BlossomAuthorization> {
  set type(BlossomAuthorizationType value) =>
      event.setTagValue('t', value.name);
  set content(String value) => event.content = value;
  set expiration(DateTime value) =>
      event.setTagValue('expiration', value.toSeconds().toString());
  set server(String value) => event.setTagValue('server', value);
  set mimeType(String value) => event.setTagValue('m', value);

  void addHash(String hash) {
    event.addTagValue('x', hash);
  }
}

enum BlossomAuthorizationType { get, upload, list, delete }

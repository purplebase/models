part of models;

class BunkerAuthorization extends EphemeralModel<BunkerAuthorization> {
  BunkerAuthorization.fromMap(super.map, super.ref) : super.fromMap();

  String get content => event.content;
  String get pubkey => event.getFirstTagValue('p')!;
}

class PartialBunkerAuthorization
    extends EphemeralPartialModel<BunkerAuthorization> {
  set content(String value) => event.content = value;
  set pubkey(String value) => event.setTagValue('p', value);
}

enum BunkerAuthorizationType { get, upload, list, delete }

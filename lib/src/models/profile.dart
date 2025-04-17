part of models;

class Profile extends ReplaceableEvent<Profile> {
  late final HasMany<Note> notes;
  late final BelongsTo<ContactList> contactList;

  Profile.fromMap(super.map, super.ref) : super.fromMap() {
    notes = HasMany(ref, RequestFilter(authors: {internal.pubkey}));
    contactList =
        BelongsTo(ref, RequestFilter<ContactList>(authors: {internal.pubkey}));
  }

  @override
  Future<Map<String, dynamic>> processMetadata() async {
    final map = jsonDecode(internal.content);
    var name = map['name'] as String?;
    if (name == null || name.isEmpty) {
      name = map['display_name'] as String?;
    }
    if (name == null || name.isEmpty) {
      name = map['displayName'] as String?;
    }
    return {
      'name': name,
      'nip05': map['nip05'],
      'pictureUrl': map['picture'],
      'lud16': map['lud16'],
    };
  }

  @override
  Map<String, dynamic> transformEventMap(Map<String, dynamic> event) {
    // As content was processed into metadata, it can be safely removed
    event['content'] = '';
    return event;
  }

  String get pubkey => internal.pubkey;
  String get npub => bech32Encode('npub', pubkey);
  String? get name => internal.metadata['name'];
  String? get nip05 => internal.metadata['nip05'];
  String? get pictureUrl => internal.metadata['picture'];
  String? get lud16 => internal.metadata['lud16'];

  String get nameOrNpub => name ?? npub;

  /// Attempts to convert this string (hex) to npub. Returns same if already npub.
  static String npubFromHex(String hex) =>
      hex.startsWith('npub') ? hex : bech32Encode('npub', hex);

  /// Attempts to convert this string (npub) to a hex pubkey. Returns same if already hex pubkey.
  static String hexFromNpub(String npub) =>
      npub.startsWith('npub') ? bech32Decode(npub) : npub;

  static String getPublicKey(String privateKey) {
    return bip340.getPublicKey(privateKey).toLowerCase();
  }
}

class PartialProfile extends ReplaceablePartialEvent<Profile> {
  PartialProfile({this.name, this.nip05, this.pictureUrl, this.lud16}) {
    internal.content =
        jsonEncode({'name': name, 'nip05': nip05, 'picture': pictureUrl});
  }

  String? name;
  String? nip05;
  String? pictureUrl;
  String? lud16;
}

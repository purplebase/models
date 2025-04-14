import 'dart:convert';

import 'package:models/models.dart';
import 'package:models/src/core/encoding.dart';
import 'package:bip340/bip340.dart' as bip340;
import 'package:models/src/models/contact_list.dart';

class Profile extends ReplaceableEvent<Profile> {
  late final Map<String, dynamic> _content;
  late final HasMany<Note> notes;
  late final BelongsTo<ContactList> contactList;

  Profile.fromMap(super.map, super.ref) : super.fromMap() {
    _content = internal.content.isNotEmpty ? jsonDecode(internal.content) : {};
    notes = HasMany(
        ref,
        RequestFilter(
            kinds: {Event.kindFor<Note>()}, authors: {internal.pubkey}));
    contactList = BelongsTo(
        ref,
        RequestFilter(
            kinds: {Event.kindFor<ContactList>()}, authors: {internal.pubkey}));
  }

  String get pubkey => internal.pubkey;
  String get npub => bech32Encode('npub', pubkey);

  String? get name {
    var name = _content['name'] as String?;
    if (name == null || name.isEmpty) {
      name = _content['display_name'] as String?;
    }
    if (name == null || name.isEmpty) {
      name = _content['displayName'] as String?;
    }
    return name;
  }

  String? get nip05 => _content['nip05'];
  String? get pictureUrl => _content['picture'];
  String? get lud16 => _content['lud16'];
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

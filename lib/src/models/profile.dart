import 'dart:convert';

import 'package:bech32/bech32.dart';
import 'package:convert/convert.dart';
import 'package:models/models.dart';

class Profile extends ReplaceableEvent<Profile> {
  late final Map<String, dynamic> _content;
  late final HasMany<Note> notes;

  Profile.fromJson(super.map, super.ref) : super.fromJson() {
    _content = internal.content.isNotEmpty ? jsonDecode(internal.content) : {};
    notes = HasMany(ref, RequestFilter(kinds: {1}, authors: {internal.pubkey}));
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
}

class PartialProfile extends ReplaceablePartialEvent<Profile> {
  PartialProfile({this.name, this.nip05, this.pictureUrl, this.lud16});

  String? name;
  String? nip05;
  String? pictureUrl;
  String? lud16;

  @override
  Future<Profile> signWith(Signer signer, {String? withPubkey}) {
    internal.content =
        jsonEncode({'name': name, 'nip05': nip05, 'picture': pictureUrl});
    return super.signWith(signer, withPubkey: withPubkey);
  }
}

// Extensions

extension Bech32StringX on String {
  /// Attempts to convert this string (hex) to npub. Returns same if already npub.
  String get npub => startsWith('npub') ? this : bech32Encode('npub', this);

  /// Attempts to convert this string (npub) to a hex pubkey. Returns same if already hex pubkey.
  String get hexKey => startsWith('npub') ? bech32Decode(this) : this;
}

String bech32Encode(String prefix, String hexData) {
  final data = hex.decode(hexData);
  final convertedData = convertBits(data, 8, 5, true);
  final bech32Data = Bech32(prefix, convertedData);
  return bech32.encode(bech32Data);
}

String bech32Decode(String bech32Data) {
  final decodedData = bech32.decode(bech32Data);
  final convertedData = convertBits(decodedData.data, 5, 8, false);
  return hex.encode(convertedData);
}

List<int> convertBits(List<int> data, int fromBits, int toBits, bool pad) {
  var acc = 0;
  var bits = 0;
  final maxv = (1 << toBits) - 1;
  final result = <int>[];

  for (final value in data) {
    if (value < 0 || value >> fromBits != 0) {
      throw Exception('Invalid value: $value');
    }
    acc = (acc << fromBits) | value;
    bits += fromBits;

    while (bits >= toBits) {
      bits -= toBits;
      result.add((acc >> bits) & maxv);
    }
  }

  if (pad) {
    if (bits > 0) {
      result.add((acc << (toBits - bits)) & maxv);
    }
  } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0) {
    throw Exception('Invalid data');
  }

  return result;
}

part of models;

/// Sealed class representing different types of shareable identifier inputs
sealed class ShareableIdentifierInput {
  const ShareableIdentifierInput({this.relays, this.author, this.kind});

  final List<String>? relays;
  final String? author;
  final int? kind;
}

/// Input for encoding a profile (nprofile)
class ProfileInput extends ShareableIdentifierInput {
  const ProfileInput({
    required this.pubkey,
    super.relays,
    super.author,
    super.kind,
  });

  final String pubkey;
}

/// Input for encoding an event (nevent)
class EventInput extends ShareableIdentifierInput {
  const EventInput({
    required this.eventId,
    super.relays,
    super.author,
    super.kind,
  });

  final String eventId;
}

/// Input for encoding an addressable event (naddr)
class AddressInput extends ShareableIdentifierInput {
  const AddressInput({
    required this.identifier,
    super.relays,
    super.author,
    super.kind,
  });

  final String identifier;
}

/// Input for encoding a public key (npub)
class NpubInput extends ShareableIdentifierInput {
  const NpubInput({required this.value}) : super();
  final String value;
}

/// Input for encoding a private key (nsec)
class NsecInput extends ShareableIdentifierInput {
  const NsecInput({required this.value}) : super();
  final String value;
}

/// Input for encoding a note/event id (note)
class NoteInput extends ShareableIdentifierInput {
  const NoteInput({required this.value}) : super();
  final String value;
}

/// Sealed class representing decoded shareable identifier data
sealed class ShareableIdentifierData {
  const ShareableIdentifierData({
    required this.relays,
    required this.author,
    required this.kind,
  });

  final List<String>? relays;
  final String? author;
  final int? kind;
}

/// Decoded profile data (nprofile, npub)
class ProfileData extends ShareableIdentifierData {
  const ProfileData({
    required this.pubkey,
    super.relays,
    super.author,
    super.kind,
  });

  final String pubkey;
}

/// Decoded event data (nevent, note)
class EventData extends ShareableIdentifierData {
  const EventData({
    required this.eventId,
    super.relays,
    super.author,
    super.kind,
  });

  final String eventId;
}

/// Decoded address data (naddr)
class AddressData extends ShareableIdentifierData {
  const AddressData({
    required this.identifier,
    super.relays,
    super.author,
    super.kind,
  });

  final String identifier;
}

/// Internal function to encode shareable identifiers (nprofile, nevent, naddr) as TLV data
/// Credit: https://github.com/ethicnology/dart-nostr/blob/master/lib/src/nips/nip_019.dart
String _encodeShareableIdentifiers({
  required String prefix,
  required String special,
  List<String>? relays,
  String? author,
  int? kind,
}) {
  // 0: special
  if (prefix == 'naddr') {
    special = special.codeUnits
        .map((number) => number.toRadixString(16).padLeft(2, '0'))
        .join();
  }
  var result =
      '00${hex.decode(special).length.toRadixString(16).padLeft(2, '0')}$special';

  // 1: relay
  if (relays != null) {
    for (final relay in relays) {
      result = '${result}01';
      final value = relay.codeUnits
          .map((number) => number.toRadixString(16).padLeft(2, '0'))
          .join();
      result =
          '$result${hex.decode(value).length.toRadixString(16).padLeft(2, '0')}$value';
    }
  }

  // 2: author
  if (author != null) {
    result = '${result}02';
    result =
        '$result${hex.decode(author).length.toRadixString(16).padLeft(2, '0')}$author';
  }

  // 3: kind
  if (kind != null) {
    result = '${result}03';
    final byteData = ByteData(4);
    byteData.setUint32(0, kind);
    final value = List.generate(
      byteData.lengthInBytes,
      (index) => byteData.getUint8(index).toRadixString(16).padLeft(2, '0'),
    ).join();
    result =
        '$result${hex.decode(value).length.toRadixString(16).padLeft(2, '0')}$value';
  }
  return _bech32Encode(prefix, result, maxLength: result.length + 90);
}

/// Internal function to decode shareable identifiers (nprofile, nevent, naddr) from TLV data
/// Returns a map with decoded values based on the identifier type
Map<String, dynamic> _decodeShareableIdentifier(String identifier) {
  // Extract prefix and data
  final parts = identifier.split('1');
  if (parts.length != 2) {
    throw Exception('Invalid shareable identifier format');
  }

  final prefix = parts[0];

  // Decode the bech32 data with appropriate maxLength
  final hexData = _bech32Decode(identifier, maxLength: identifier.length);

  // Parse TLV data
  final result = <String, dynamic>{};
  var offset = 0;

  while (offset < hexData.length) {
    if (offset + 2 > hexData.length) break;

    // Read type (1 byte)
    final type = int.parse(hexData.substring(offset, offset + 2), radix: 16);
    offset += 2;

    if (offset + 2 > hexData.length) break;

    // Read length (1 byte)
    final length = int.parse(hexData.substring(offset, offset + 2), radix: 16);
    offset += 2;

    if (offset + length * 2 > hexData.length) break;

    // Read value
    final valueHex = hexData.substring(offset, offset + length * 2);
    offset += length * 2;

    switch (type) {
      case 0: // special (pubkey for nprofile, event id for nevent, etc.)
        // For naddr, decode the hex back to string
        if (prefix == 'naddr') {
          result['special'] = utf8.decode(hex.decode(valueHex));
        } else {
          result['special'] = valueHex;
        }
        break;
      case 1: // relay
        final relay = utf8.decode(hex.decode(valueHex));
        if (result['relays'] == null) {
          result['relays'] = <String>[];
        }
        result['relays'].add(relay);
        break;
      case 2: // author
        result['author'] = valueHex;
        break;
      case 3: // kind
        final bytes = hex.decode(valueHex);
        if (bytes.length == 4) {
          final byteData = ByteData.view(Uint8List.fromList(bytes).buffer);
          result['kind'] = byteData.getUint32(0);
        }
        break;
    }
  }

  return result;
}

String _bech32Encode(String prefix, String hexData, {int? maxLength}) {
  // Left pad hexData with '0' to ensure it is 64 characters long
  if (hexData.length < 64) {
    hexData = hexData.padLeft(64, '0');
  }
  final data = hex.decode(hexData);
  final convertedData = _convertBits(data, 8, 5, true);
  final bech32Data = Bech32(prefix, convertedData);
  if (maxLength != null) return bech32.encode(bech32Data, maxLength);
  return bech32.encode(bech32Data);
}

String _bech32Decode(String bech32Data, {int? maxLength}) {
  final decodedData = maxLength != null
      ? bech32.decode(bech32Data, maxLength)
      : bech32.decode(bech32Data);
  final convertedData = _convertBits(decodedData.data, 5, 8, false);
  return hex.encode(convertedData);
}

List<int> _convertBits(List<int> data, int fromBits, int toBits, bool pad) {
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

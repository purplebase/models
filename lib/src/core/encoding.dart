import 'dart:typed_data';

import 'package:bech32/bech32.dart';
import 'package:convert/convert.dart';

/// Encode shareable identifiers (nprofile, nevent, naddr) as TLV data
/// Credit: https://github.com/ethicnology/dart-nostr/blob/master/lib/src/nips/nip_019.dart
String encodeShareableIdentifiers({
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
        (index) =>
            byteData.getUint8(index).toRadixString(16).padLeft(2, '0')).join();
    result =
        '$result${hex.decode(value).length.toRadixString(16).padLeft(2, '0')}$value';
  }
  return bech32Encode(prefix, result, maxLength: result.length + 90);
}

String bech32Encode(String prefix, String hexData, {int? maxLength}) {
  final data = hex.decode(hexData);
  final convertedData = convertBits(data, 8, 5, true);
  final bech32Data = Bech32(prefix, convertedData);
  if (maxLength != null) return bech32.encode(bech32Data, maxLength);
  return bech32.encode(bech32Data);
}

/// For these events, the contents are a binary-encoded list of TLV (type-length-value),
/// with T and L being 1 byte each (uint8, i.e. a number in the range of 0-255),
///  and V being a sequence of bytes of the size indicated by L.
///
/// 0: special depends on the bech32 prefix:
/// - for nprofile it will be the 32 bytes of the profile public key
/// - for nevent it will be the 32 bytes of the event id
/// - for naddr, it is the identifier (the "d" tag) of the event being referenced. For normal replaceable events use an empty string.
///
/// 1: relay for nprofile, nevent and naddr, optionally, a relay in which the entity
/// (profile or event) is more likely to be found, encoded as ascii this may be included multiple times
///
/// 2: author
/// - for naddr, the 32 bytes of the pubkey of the event
/// - for nevent, optionally, the 32 bytes of the pubkey of the event
///
/// 3: kind
/// - for naddr, the 32-bit unsigned integer of the kind, big-endian
/// - for nevent, optionally, the 32-bit unsigned integer of the kind, big-endian
// (String, String) decodeShareableIdentifiers({
//   required String payload,
// }) {
//   try {
//     String special = '';
//     final List<String> relays = [];
//     String? author;
//     int? kind;
//     final decoded = bech32Decode(payload, maxLength: payload.length);
//     final data = hex.decode(decoded.data);

//     var index = 0;
//     while (index < data.length) {
//       final type = data[index++];
//       final length = data[index++];

//       final value = Uint8List.fromList(data.sublist(index, index + length));
//       index += length;

//       if (type == 0) {
//         special = (decoded.prefix == Nip19Prefix.naddr)
//             ? String.fromCharCodes(value)
//             : hex.encode(value);
//       } else if (type == 1) {
//         relays.add(String.fromCharCodes(value));
//       } else if (type == 2) {
//         author = hex.encode(value);
//       } else if (type == 3) {
//         final byteData = ByteData.sublistView(value);
//         kind = byteData.getUint32(0);
//       }
//     }

//     return ShareableIdentifiers(
//       prefix: decoded.prefix,
//       special: special,
//       relays: relays,
//       author: author,
//       kind: kind,
//     );
//   } catch (e) {
//     throw Exception('Failed to decode shareable entity: $e');
//   }
// }

String bech32Decode(String bech32Data, {int? maxLength}) {
  final decodedData = maxLength != null
      ? bech32.decode(bech32Data, maxLength)
      : bech32.decode(bech32Data);
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

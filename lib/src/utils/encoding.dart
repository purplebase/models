import 'dart:convert';
import 'dart:typed_data';

import 'package:bech32/bech32.dart';
import 'package:convert/convert.dart';

/// Sealed class representing different types of shareable identifier inputs
sealed class ShareableIdentifierInput {
  const ShareableIdentifierInput({this.relays, this.author, this.kind});

  final List<String>? relays;
  final String? author;
  final int? kind;
}

class ProfileInput extends ShareableIdentifierInput {
  const ProfileInput({
    required this.pubkey,
    super.relays,
    super.author,
    super.kind,
  });
  final String pubkey;
}

class EventInput extends ShareableIdentifierInput {
  const EventInput({
    required this.eventId,
    super.relays,
    super.author,
    super.kind,
  });
  final String eventId;
}

class AddressInput extends ShareableIdentifierInput {
  const AddressInput({
    required this.identifier,
    super.relays,
    super.author,
    super.kind,
  });
  final String identifier;
}

class NpubInput extends ShareableIdentifierInput {
  const NpubInput({required this.value}) : super();
  final String value;
}

class NsecInput extends ShareableIdentifierInput {
  const NsecInput({required this.value}) : super();
  final String value;
}

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

class ProfileData extends ShareableIdentifierData {
  const ProfileData({
    required this.pubkey,
    super.relays,
    super.author,
    super.kind,
  });
  final String pubkey;
}

class EventData extends ShareableIdentifierData {
  const EventData({
    required this.eventId,
    super.relays,
    super.author,
    super.kind,
  });
  final String eventId;
}

class AddressData extends ShareableIdentifierData {
  const AddressData({
    required this.identifier,
    super.relays,
    super.author,
    super.kind,
  });
  final String identifier;
}

// Package-visible encoding functions (no underscore prefix)

String encodeShareableIdentifiers({
  required String prefix,
  required String special,
  List<String>? relays,
  String? author,
  int? kind,
}) {
  if (prefix == 'naddr') {
    special = special.codeUnits
        .map((number) => number.toRadixString(16).padLeft(2, '0'))
        .join();
  }
  var result =
      '00${hex.decode(special).length.toRadixString(16).padLeft(2, '0')}$special';

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

  if (author != null) {
    result = '${result}02';
    result =
        '$result${hex.decode(author).length.toRadixString(16).padLeft(2, '0')}$author';
  }

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
  return bech32Encode(prefix, result, maxLength: result.length + 90);
}

Map<String, dynamic> decodeShareableIdentifierRaw(String identifier) {
  final parts = identifier.split('1');
  if (parts.length != 2) {
    throw Exception('Invalid shareable identifier format');
  }

  final prefix = parts[0];
  final hexData = bech32Decode(identifier, maxLength: identifier.length);

  final result = <String, dynamic>{};
  var offset = 0;

  while (offset < hexData.length) {
    if (offset + 2 > hexData.length) break;

    final type = int.parse(hexData.substring(offset, offset + 2), radix: 16);
    offset += 2;

    if (offset + 2 > hexData.length) break;

    final length = int.parse(hexData.substring(offset, offset + 2), radix: 16);
    offset += 2;

    if (offset + length * 2 > hexData.length) break;

    final valueHex = hexData.substring(offset, offset + length * 2);
    offset += length * 2;

    switch (type) {
      case 0:
        if (prefix == 'naddr') {
          result['special'] = utf8.decode(hex.decode(valueHex));
        } else {
          result['special'] = valueHex;
        }
        break;
      case 1:
        final relay = utf8.decode(hex.decode(valueHex));
        if (result['relays'] == null) {
          result['relays'] = <String>[];
        }
        result['relays'].add(relay);
        break;
      case 2:
        result['author'] = valueHex;
        break;
      case 3:
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

String bech32Encode(String prefix, String hexData, {int? maxLength}) {
  if (hexData.length < 64) {
    hexData = hexData.padLeft(64, '0');
  }
  final data = hex.decode(hexData);
  final convertedData = _convertBits(data, 8, 5, true);
  final bech32Data = Bech32(prefix, convertedData);
  if (maxLength != null) return bech32.encode(bech32Data, maxLength);
  return bech32.encode(bech32Data);
}

String bech32Decode(String bech32Data, {int? maxLength}) {
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

part of models;

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

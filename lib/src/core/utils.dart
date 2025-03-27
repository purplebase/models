import 'dart:convert';
import 'dart:typed_data';

import 'package:bech32/bech32.dart';
import 'package:bip340/bip340.dart' as bip340;
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';

typedef EventConstructor<E extends Event<E>> = E Function(
    Map<String, dynamic>, Ref ref);

typedef ReplaceableEventLink = (int, String, String?);

extension ReplaceableEventLinkExt on ReplaceableEventLink {
  // NOTE: Yes, plain replaceables have a trailing colon
  String get formatted => '${this.$1}:${this.$2}:${this.$3 ?? ''}';
}

extension PartialEventExt on PartialEvent {
  String getEventId(String pubkey) {
    final data = [
      0,
      pubkey.toLowerCase(),
      internal.createdAt.toSeconds(),
      internal.kind,
      TagValue.serialize(internal.tags),
      internal.content
    ];
    final digest =
        sha256.convert(Uint8List.fromList(utf8.encode(json.encode(data))));
    return digest.toString();
  }
}

extension StringMaybeExt on String? {
  int? toInt() {
    return this == null ? null : int.tryParse(this!);
  }
}

extension DateTimeExt on DateTime {
  int toSeconds() => millisecondsSinceEpoch ~/ 1000;
}

extension IntExt on int {
  DateTime toDate() => DateTime.fromMillisecondsSinceEpoch(this * 1000);
}

extension StringExt on String {
  ReplaceableEventLink toReplaceableLink() {
    final [kind, pubkey, ...identifier] = split(':');
    return (kind.toInt()!, pubkey, identifier.firstOrNull);
  }
}

class BaseUtil {
  static String getPublicKey(String privateKey) {
    return bip340.getPublicKey(privateKey).toLowerCase();
  }
}

final kBolt11Regexp = RegExp(r'lnbc(\d+)([munp])');

int getSatsFromBolt11(String bolt11) {
  try {
    final m = kBolt11Regexp.allMatches(bolt11);
    final [baseAmountInBitcoin, multiplier] = m.first.groups([1, 2]);
    final a = int.tryParse(baseAmountInBitcoin!)!;
    final amountInBitcoin = switch (multiplier!) {
      'm' => a * 0.001,
      'u' => a * 0.000001,
      'n' => a * 0.000000001,
      'p' => a * 0.000000000001,
      _ => a,
    };
    // Return converted to sats
    return (amountInBitcoin * 100000000).floor();
  } catch (_) {
    // Do not bother throwing an exception, 0 sat should still convey that it was an error
    return 0;
  }
}

///
///

/// Encodes a Nostr event ID into the nevent bech32 format
String encodeNevent({
  required String id,
  String? author,
  List<String>? relays,
  String? kind,
}) {
  // Convert data to TLV (Type-Length-Value) format
  List<int> data = [];

  // Add ID (type 0)
  final idBytes = HEX.decode(id);
  data.add(0); // type
  data.add(idBytes.length); // length
  data.addAll(idBytes); // value

  // Add author pubkey if provided (type 1)
  if (author != null) {
    final authorBytes = HEX.decode(author);
    data.add(1); // type
    data.add(authorBytes.length); // length
    data.addAll(authorBytes); // value
  }

  // Add kind if provided (type 3)
  if (kind != null) {
    final kindInt = int.parse(kind);
    data.add(3); // type
    data.add(4); // length for 32-bit integer
    // Add 32-bit integer in big-endian format
    data.add((kindInt >> 24) & 0xff);
    data.add((kindInt >> 16) & 0xff);
    data.add((kindInt >> 8) & 0xff);
    data.add(kindInt & 0xff);
  }

  // Add relays if provided (type 2)
  if (relays != null && relays.isNotEmpty) {
    for (final relay in relays) {
      final relayBytes = utf8.encode(relay);
      data.add(2); // type
      data.add(relayBytes.length); // length
      data.addAll(relayBytes); // value
    }
  }

  // Convert to Bech32 format
  return bech32.encode(Bech32('nevent', data));
}

/// Decodes a Nostr nevent bech32 string back to its components
Map<String, dynamic> decodeNevent(String nevent) {
  final result = <String, dynamic>{};
  final decoded = bech32.decode(nevent);

  if (decoded.hrp != 'nevent') {
    throw FormatException('Not a valid nevent: hrp is not "nevent"');
  }

  final data = decoded.data;
  int i = 0;

  while (i < data.length) {
    final type = data[i++];
    final length = data[i++];

    // Extract value based on type
    switch (type) {
      case 0: // ID
        final idBytes = data.sublist(i, i + length);
        result['id'] = HEX.encode(idBytes);
        i += length;
        break;

      case 1: // Author
        final authorBytes = data.sublist(i, i + length);
        result['author'] = HEX.encode(authorBytes);
        i += length;
        break;

      case 2: // Relay
        final relayBytes = data.sublist(i, i + length);
        final relay = utf8.decode(relayBytes);
        if (!result.containsKey('relays')) {
          result['relays'] = <String>[];
        }
        (result['relays'] as List<String>).add(relay);
        i += length;
        break;

      case 3: // Kind
        if (length == 4) {
          final k1 = data[i];
          final k2 = data[i + 1];
          final k3 = data[i + 2];
          final k4 = data[i + 3];
          final kind = (k1 << 24) | (k2 << 16) | (k3 << 8) | k4;
          result['kind'] = kind.toString();
          i += 4;
        } else {
          throw FormatException('Invalid kind length in nevent format');
        }
        break;

      default:
        // Skip unknown types
        i += length;
    }
  }

  return result;
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:bip340/bip340.dart' as bip340;
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
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
      Event.serializeTags(internal.tags),
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

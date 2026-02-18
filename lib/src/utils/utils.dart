import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bip340/bip340.dart' as bip340;
import 'package:crypto/crypto.dart';

import '../core/event.dart';
import 'encoding.dart';
import 'extensions.dart';

class Utils {
  // Keys

  /// Cryptographically secure random number formatted as 64-character hex
  static String generateRandomHex64() {
    final random = math.Random.secure();
    final values = Uint8List(32);
    for (var i = 0; i < values.length; i++) {
      values[i] = random.nextInt(256);
    }
    return values.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Get the public key corresponding to the supplied private key
  static String derivePublicKey(String privateKey) {
    return bip340.getPublicKey(privateKey).toLowerCase();
  }

  // Encoding

  /// Encode a shareable identifier from typed input
  static String encodeShareableIdentifier(ShareableIdentifierInput input) {
    return switch (input) {
      NpubInput(:final value) => bech32Encode('npub', value),
      NsecInput(:final value) => bech32Encode('nsec', value),
      NoteInput(:final value) => bech32Encode('note', value),
      ProfileInput(:final pubkey, :final relays, :final author, :final kind) =>
        encodeShareableIdentifiers(
          prefix: 'nprofile',
          special: pubkey,
          relays: relays,
          author: author,
          kind: kind,
        ),
      EventInput(:final eventId, :final relays, :final author, :final kind) =>
        encodeShareableIdentifiers(
          prefix: 'nevent',
          special: eventId,
          relays: relays,
          author: author,
          kind: kind,
        ),
      AddressInput(
        :final identifier,
        :final relays,
        :final author,
        :final kind,
      ) =>
        encodeShareableIdentifiers(
          prefix: 'naddr',
          special: identifier,
          relays: relays,
          author: author,
          kind: kind,
        ),
    };
  }

  /// Decode a shareable identifier to typed output
  static ShareableIdentifierData decodeShareableIdentifier(String identifier) {
    if (identifier.startsWith('nostr:')) {
      identifier = identifier.substring(6);
    }

    final prefix = identifier.split('1')[0];
    final raw = decodeShareableIdentifierRaw(identifier);

    return switch (prefix) {
      'npub' => ProfileData(pubkey: bech32Decode(identifier)),
      'nprofile' => ProfileData(
          pubkey: raw['special'] as String,
          relays: raw['relays'] as List<String>?,
          author: raw['author'] as String?,
          kind: raw['kind'] as int?,
        ),
      'note' => EventData(eventId: bech32Decode(identifier)),
      'nevent' => EventData(
          eventId: raw['special'] as String,
          relays: raw['relays'] as List<String>?,
          author: raw['author'] as String?,
          kind: raw['kind'] as int?,
        ),
      'naddr' => AddressData(
          identifier: raw['special'] as String,
          relays: raw['relays'] as List<String>?,
          author: raw['author'] as String?,
          kind: raw['kind'] as int?,
        ),
      _ => throw Exception('Unknown shareable identifier prefix: $prefix'),
    };
  }

  /// Encode a simple string to NIP-19 format
  static String encodeShareableFromString(
    String value, {
    required String type,
  }) {
    if (value.startsWith('npub') ||
        value.startsWith('nsec') ||
        value.startsWith('note') ||
        value.startsWith('nprofile') ||
        value.startsWith('nevent') ||
        value.startsWith('naddr')) {
      return value;
    }

    final input = switch (type) {
      'nsec' => NsecInput(value: value),
      'npub' => NpubInput(value: value),
      'note' => NoteInput(value: value),
      'nprofile' => ProfileInput(pubkey: value),
      'nevent' => EventInput(eventId: value),
      _ => throw Exception('Unknown type: $type'),
    };
    return encodeShareableIdentifier(input);
  }

  /// Convenience method to decode NIP-19 entities into a simple string
  static String decodeShareableToString(String input) {
    if (!(input.startsWith('npub') ||
        input.startsWith('nsec') ||
        input.startsWith('note') ||
        input.startsWith('nprofile') ||
        input.startsWith('nevent') ||
        input.startsWith('naddr') ||
        input.startsWith('nostr:'))) {
      return input;
    }

    if (input.startsWith('nostr:')) {
      input = input.substring(6);
    }

    if (input.startsWith('npub') ||
        input.startsWith('nsec') ||
        input.startsWith('note')) {
      return bech32Decode(input);
    }

    final data = decodeShareableIdentifier(input);
    if (data is ProfileData) {
      return data.pubkey;
    } else if (data is EventData) {
      return data.eventId;
    } else if (data is AddressData) {
      return data.identifier;
    } else {
      throw Exception(
        'Unknown decoded shareable identifier type: ${data.runtimeType}',
      );
    }
  }

  /// Decode NIP-05 identifier to public key
  static Future<String> decodeNip05(
    String address, {
    dynamic client,
  }) async {
    throw UnimplementedError(
        'decodeNip05 requires an HTTP client. Use the provider-level implementation.');
  }

  // Events

  static String getEventId(PartialEvent event, String pubkey) {
    final data = [
      0,
      pubkey.toLowerCase(),
      event.createdAt.toSeconds(),
      event.kind,
      event.tags,
      event.content,
    ];
    final digest = sha256.convert(
      Uint8List.fromList(utf8.encode(json.encode(data))),
    );
    return digest.toString();
  }

  static bool isEventReplaceable(int kind) {
    return switch (kind) {
      >= 10000 && < 20000 || 0 || 3 || >= 30000 && < 40000 => true,
      _ => false,
    };
  }

  /// Extract URLs from imeta tags
  static List<String> extractImetaUrls(Set<List<String>> imetaTags) {
    final urls = <String>[];
    for (final tag in imetaTags) {
      for (int i = 1; i < tag.length; i++) {
        final part = tag[i];
        if (part.startsWith('url ')) {
          final url = part.substring(4);
          if (url.isNotEmpty) {
            urls.add(url);
          }
        }
      }
    }
    return urls;
  }
}

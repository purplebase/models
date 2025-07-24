part of models;

class Utils {
  // Keys

  /// Crytographically secure random number formatted as 64-character hex
  static String generateRandomHex64() {
    final random = Random.secure();
    final values = Uint8List(32); // 32 bytes = 256 bits

    // Fill the byte array with random values
    for (var i = 0; i < values.length; i++) {
      values[i] = random.nextInt(256);
    }

    // Convert each byte to a 2-digit hex representation
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
      NpubInput(:final value) => _bech32Encode('npub', value),
      NsecInput(:final value) => _bech32Encode('nsec', value),
      NoteInput(:final value) => _bech32Encode('note', value),
      ProfileInput(:final pubkey, :final relays, :final author, :final kind) =>
        _encodeShareableIdentifiers(
          prefix: 'nprofile',
          special: pubkey,
          relays: relays,
          author: author,
          kind: kind,
        ),
      EventInput(:final eventId, :final relays, :final author, :final kind) =>
        _encodeShareableIdentifiers(
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
        _encodeShareableIdentifiers(
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
    // Handle NIP-21 URIs which is the identifier prepended by "nostr:"
    if (identifier.startsWith('nostr:')) {
      identifier = identifier.substring(6); // Remove "nostr:" prefix
    }

    final prefix = identifier.split('1')[0];

    final raw = _decodeShareableIdentifier(identifier);

    return switch (prefix) {
      'npub' => ProfileData(pubkey: _bech32Decode(identifier)),
      'nprofile' => ProfileData(
        pubkey: raw['special'] as String,
        relays: raw['relays'] as List<String>?,
        author: raw['author'] as String?,
        kind: raw['kind'] as int?,
      ),
      'note' => EventData(eventId: _bech32Decode(identifier)),
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
    // Check if already encoded before calling _bech32Encode
    if (value.startsWith('npub') ||
        value.startsWith('nsec') ||
        value.startsWith('note') ||
        value.startsWith('nprofile') ||
        value.startsWith('nevent') ||
        value.startsWith('naddr')) {
      // Already encoded, return as is
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
    // If not a well-known NIP-19 entity, return as-is (already decoded)
    if (!(input.startsWith('npub') ||
        input.startsWith('nsec') ||
        input.startsWith('note') ||
        input.startsWith('nprofile') ||
        input.startsWith('nevent') ||
        input.startsWith('naddr') ||
        input.startsWith('nostr:'))) {
      return input;
    }

    // Handle NIP-21 URIs
    if (input.startsWith('nostr:')) {
      input = input.substring(6);
    }

    // Handle simple bech32 formats (npub, nsec, note)
    if (input.startsWith('npub')) {
      return _bech32Decode(input);
    } else if (input.startsWith('nsec')) {
      return _bech32Decode(input);
    } else if (input.startsWith('note')) {
      return _bech32Decode(input);
    }

    // Handle complex formats (nprofile, nevent, naddr)
    final data = decodeShareableIdentifier(input);
    if (data is ProfileData) {
      return data.pubkey;
    } else if (data is EventData) {
      return data.eventId;
    } else if (data is AddressData) {
      return data.identifier;
    } else {
      throw Exception(
        'Unknown decoded shareable identifier type: \\${data.runtimeType}',
      );
    }
  }

  /// Decode NIP-05 identifier to public key
  static Future<String> decodeNip05(String address) async {
    try {
      final [username, domain] = address.split('@');

      // Make HTTP request to .well-known/nostr.json
      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('https://$domain/.well-known/nostr.json?name=$username'),
        );
        final response = await request.close();

        if (response.statusCode != 200) {
          throw Exception(
            'HTTP ${response.statusCode}: Failed to fetch NIP-05 data',
          );
        }

        final responseBody = await response.transform(utf8.decoder).join();
        final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;

        final names = jsonData['names'] as Map<String, dynamic>?;
        if (names == null) {
          throw Exception('No names field in NIP-05 response');
        }

        final pubkey = names[username] as String?;
        if (pubkey == null) {
          throw Exception('Username $username not found in NIP-05 response');
        }

        return pubkey;
      } finally {
        client.close();
      }
    } catch (e) {
      throw Exception('Failed to decode NIP-05 identifier: $e');
    }
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

  static isEventReplaceable(int kind) {
    return switch (kind) {
      >= 10000 && < 20000 || 0 || 3 || >= 30000 && < 40000 => true,
      _ => false,
    };
  }
}

part of models;

class Utils {
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

  /// Attempts to convert this string (hex) to npub. Returns same if already npub.
  static String npubFromHex(String hex) =>
      hex.startsWith('npub') ? hex : bech32Encode('npub', hex);

  /// Attempts to convert this string (npub) to a hex pubkey. Returns same if already hex pubkey.
  static String hexFromNpub(String npub) =>
      npub.startsWith('npub') ? bech32Decode(npub) : npub;

  /// Get the public key corresponding to the supplied private key
  static String getPublicKey(String privateKey) {
    return bip340.getPublicKey(privateKey).toLowerCase();
  }

  static String getEventId(PartialEvent event, String pubkey) {
    final data = [
      0,
      pubkey.toLowerCase(),
      event.createdAt.toSeconds(),
      event.kind,
      event.tags,
      event.content
    ];
    final digest =
        sha256.convert(Uint8List.fromList(utf8.encode(json.encode(data))));
    return digest.toString();
  }
}

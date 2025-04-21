part of models;

class Utils {
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
}

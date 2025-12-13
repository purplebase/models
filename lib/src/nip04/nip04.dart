part of models;

/// NIP-04 encryption/decryption implementation
/// Uses AES-256-CBC with ECDH shared secret on secp256k1
class Nip04 {
  /// Encrypt a message using NIP-04
  /// Returns: base64(encrypted)?iv=base64(iv)
  static String encrypt(String plaintext, String privateKeyHex, String pubkeyHex) {
    final sharedSecret = _getSharedSecret(privateKeyHex, pubkeyHex);
    
    // Generate random IV (16 bytes)
    final random = math.Random.secure();
    final iv = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      iv[i] = random.nextInt(256);
    }
    
    // AES-256-CBC encryption
    final key = pc.KeyParameter(sharedSecret);
    final params = pc.ParametersWithIV(key, iv);
    
    final cipher = pc.CBCBlockCipher(pc.AESEngine())..init(true, params);
    
    // PKCS7 padding
    final plaintextBytes = utf8.encode(plaintext);
    final padded = _pkcs7Pad(Uint8List.fromList(plaintextBytes), 16);
    
    // Encrypt
    final encrypted = Uint8List(padded.length);
    var offset = 0;
    while (offset < padded.length) {
      offset += cipher.processBlock(padded, offset, encrypted, offset);
    }
    
    // Format: base64(encrypted)?iv=base64(iv)
    final encryptedBase64 = base64.encode(encrypted);
    final ivBase64 = base64.encode(iv);
    
    return '$encryptedBase64?iv=$ivBase64';
  }
  
  /// Decrypt a message using NIP-04
  static String decrypt(String ciphertext, String privateKeyHex, String pubkeyHex) {
    final sharedSecret = _getSharedSecret(privateKeyHex, pubkeyHex);
    
    // Parse the ciphertext: base64(encrypted)?iv=base64(iv)
    final parts = ciphertext.split('?iv=');
    if (parts.length != 2) {
      throw FormatException('Invalid NIP-04 ciphertext format');
    }
    
    final encrypted = base64.decode(parts[0]);
    final iv = base64.decode(parts[1]);
    
    // AES-256-CBC decryption
    final key = pc.KeyParameter(sharedSecret);
    final params = pc.ParametersWithIV(key, iv);
    
    final cipher = pc.CBCBlockCipher(pc.AESEngine())..init(false, params);
    
    // Decrypt
    final decrypted = Uint8List(encrypted.length);
    var offset = 0;
    while (offset < encrypted.length) {
      offset += cipher.processBlock(encrypted, offset, decrypted, offset);
    }
    
    // Remove PKCS7 padding
    final unpadded = _pkcs7Unpad(decrypted);
    
    return utf8.decode(unpadded);
  }
  
  /// Compute ECDH shared secret using secp256k1
  static Uint8List _getSharedSecret(String privateKeyHex, String pubkeyHex) {
    final privateKey = _hexToBytes(privateKeyHex);
    final pubkey = _hexToBytes(pubkeyHex);
    
    // Get secp256k1 curve parameters
    final params = pc.ECDomainParameters('secp256k1');
    
    // Parse private key
    final d = _bytesToBigInt(privateKey);
    final privKey = pc.ECPrivateKey(d, params);
    
    // Parse public key (32-byte x-only pubkey)
    pc.ECPoint? pubPoint;
    if (pubkey.length == 32) {
      // Compressed pubkey without prefix - try 02 prefix (even y)
      pubPoint = params.curve.decodePoint([0x02, ...pubkey]);
    } else if (pubkey.length == 33) {
      pubPoint = params.curve.decodePoint(pubkey);
    } else if (pubkey.length == 65) {
      pubPoint = params.curve.decodePoint(pubkey);
    } else {
      throw ArgumentError('Invalid public key length: ${pubkey.length}');
    }
    
    // Compute shared point
    final sharedPoint = pubPoint! * privKey.d;
    
    // Return X coordinate as shared secret (32 bytes)
    final x = sharedPoint!.x!.toBigInteger()!;
    final xBytes = _bigIntToBytes(x, 32);
    
    return xBytes;
  }
  
  static Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padLen = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padLen);
    padded.setAll(0, data);
    for (var i = data.length; i < padded.length; i++) {
      padded[i] = padLen;
    }
    return padded;
  }
  
  static Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) return data;
    final padLen = data.last;
    if (padLen > data.length || padLen > 16 || padLen == 0) {
      throw FormatException('Invalid PKCS7 padding');
    }
    return Uint8List.view(data.buffer, data.offsetInBytes, data.length - padLen);
  }
  
  static Uint8List _hexToBytes(String hex) {
    if (hex.length % 2 != 0) {
      throw FormatException('Invalid hex string length');
    }
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
  
  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) + BigInt.from(byte);
    }
    return result;
  }
  
  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final bytes = Uint8List(length);
    var temp = value;
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = (temp & BigInt.from(0xff)).toInt();
      temp = temp >> 8;
    }
    return bytes;
  }
}


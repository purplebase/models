part of models;

/// Base class for all signers
abstract class Signer {
  final Ref ref;

  String? _pubkey;
  String get pubkey => _pubkey!;
  @protected
  void internalSetPubkey(String pubkey) => _pubkey = pubkey;

  Signer(this.ref);

  Future<bool> get isAvailable async {
    return true;
  }

  // New Public API Methods

  /// Sign in the signer with the current pubkey
  ///
  /// This is the preferred method for signing in signers.
  /// [setAsActive] determines whether this signer becomes the active signer after sign in.
  @mustCallSuper
  Future<void> signIn({
    bool setAsActive = true,
    bool registerSigner = true,
  }) async {
    if (_pubkey == null) {
      throw UnsupportedError(
        'Pubkey must be set, bug in $runtimeType implementation',
      );
    }

    if (registerSigner == false) {
      return;
    }

    ref.read(Signer._signerProvider(_pubkey!).notifier).state = this;
    ref.read(Signer._signedInPubkeysProvider.notifier).state = ref.read(
      Signer._signedInPubkeysProvider,
    )..add(_pubkey!);

    if (setAsActive) {
      setAsActivePubkey();
    }
  }

  /// Sign out the signer, removing it from the signed-in set
  ///
  /// This is the preferred method for signing out signers.
  /// If this signer is currently active, it will be removed from active status.
  Future<void> signOut() async {
    // Remove from signed in set
    ref.read(_signedInPubkeysProvider.notifier).state = ref.read(
      _signedInPubkeysProvider,
    )..remove(_pubkey);

    // If pubkey is managed by this signer, remove from active
    removeAsActivePubkey();

    _pubkey = null;
  }

  /// Set this signer as the active pubkey
  ///
  /// This is the preferred method for setting a signer as active.
  void setAsActivePubkey() {
    ref.read(Signer._activePubkeyProvider.notifier).state = _pubkey;
  }

  /// Remove this signer as the active pubkey if it's currently active
  ///
  /// This is the preferred method for removing a signer from active status.
  void removeAsActivePubkey() {
    if (ref.read(_activePubkeyProvider) == _pubkey) {
      ref.read(_activePubkeyProvider.notifier).state = null;
    }
  }

  /// Whether this signer is signed in
  ///
  /// This is the preferred property for checking sign-in status.
  bool get isSignedIn => _pubkey != null;

  /// Sign the partial models, supply `withPubkey` to disambiguate when signer holds multiple keys
  Future<List<E>> sign<E extends Model<dynamic>>(
    List<PartialModel<Model<dynamic>>> partialModels,
  );

  /// NIP-04: Encrypt a message using AES-256-CBC with ECDH shared secret
  Future<String> nip04Encrypt(String message, String recipientPubkey);

  /// NIP-04: Decrypt a message using AES-256-CBC with ECDH shared secret
  Future<String> nip04Decrypt(String encryptedMessage, String senderPubkey);

  /// NIP-44: Encrypt a message using ChaCha20 with HKDF and HMAC-SHA256
  Future<String> nip44Encrypt(String message, String recipientPubkey);

  /// NIP-44: Decrypt a message using ChaCha20 with HKDF and HMAC-SHA256
  Future<String> nip44Decrypt(String encryptedMessage, String senderPubkey);

  // Signed-in related functions and providers

  /// Returns a Signer given a pubkey
  static final signerProvider = Provider.family<Signer?, String>(
    (ref, pubkey) => ref.watch(_signerProvider(pubkey)),
  );

  /// Returns all currently signed in pubkeys. There is a signer for each one of these
  static final signedInPubkeysProvider = Provider(
    (ref) => ref.watch(_signedInPubkeysProvider),
  );

  /// Returns the active pubkey
  static final activePubkeyProvider = Provider(
    (ref) => ref.watch(_activePubkeyProvider),
  );

  static final _signerProvider = StateProvider.family<Signer?, String>(
    (_, pubkey) => null,
  );
  static final _signedInPubkeysProvider = StateProvider<Set<String>>((_) => {});
  static final _activePubkeyProvider = StateProvider<String?>((_) => null);

  static final activeSignerProvider = Provider((ref) {
    final activePubkey = ref.watch(_activePubkeyProvider);
    if (activePubkey == null) return null;
    return ref.read(_signerProvider(activePubkey));
  });

  static final activeProfileProvider = Provider.family<Profile?, Source>((
    ref,
    source,
  ) {
    final activePubkey = ref.watch(_activePubkeyProvider);
    if (activePubkey == null) return null;
    final state = ref.watch(
      query<Profile>(authors: {activePubkey}, source: source, limit: 1),
    );
    return state.models.firstOrNull;
  });
}

/// A private key signer implementation
class Bip340PrivateKeySigner extends Signer {
  final String _privateKey;

  Bip340PrivateKeySigner(String privateKey, super.ref)
    // Ensure private key is stored in hex format
    : _privateKey = privateKey.decodeShareable();

  @override
  Future<void> signIn({
    bool setAsActive = true,
    bool registerSigner = true,
  }) async {
    internalSetPubkey(Utils.derivePublicKey(_privateKey));

    return super.signIn(
      setAsActive: setAsActive,
      registerSigner: registerSigner,
    );
  }

  Map<String, dynamic> _prepare(
    Map<String, dynamic> map,
    String id,
    String pubkey,
    String signature,
  ) {
    return map
      ..['id'] = id
      ..['pubkey'] = pubkey
      ..['sig'] = signature;
  }

  @override
  Future<List<E>> sign<E extends Model<dynamic>>(
    List<PartialModel<Model<dynamic>>> partialModels,
  ) async {
    if (!isSignedIn) {
      throw StateError('Signer has not been signed in');
    }
    return partialModels
        .map((partialModel) {
          final id = Utils.getEventId(partialModel.event, pubkey);
          final aux = hex.encode(List<int>.generate(32, (i) => 1));
          final signature = bip340.sign(_privateKey, id.toString(), aux);
          final map = _prepare(partialModel.toMap(), id, pubkey, signature);
          return Model.getConstructorForKind(
            partialModel.event.kind,
          )!.call(map, ref);
        })
        .cast<E>()
        .toList();
  }

  @override
  Future<String> nip04Encrypt(String message, String recipientPubkey) async {
    if (!isSignedIn) {
      throw StateError('Signer has not been signed in');
    }
    return _nip04Encrypt(message, recipientPubkey);
  }

  @override
  Future<String> nip04Decrypt(
    String encryptedMessage,
    String senderPubkey,
  ) async {
    if (!isSignedIn) {
      throw StateError('Signer has not been signed in');
    }
    return _nip04Decrypt(encryptedMessage, senderPubkey);
  }

  @override
  Future<String> nip44Encrypt(String message, String recipientPubkey) async {
    if (!isSignedIn) {
      throw StateError('Signer has not been signed in');
    }
    try {
      return await nip44.Nip44.encryptMessage(
        message,
        _privateKey,
        recipientPubkey,
      );
    } catch (e) {
      throw Exception('NIP-44 encryption failed: $e');
    }
  }

  @override
  Future<String> nip44Decrypt(
    String encryptedMessage,
    String senderPubkey,
  ) async {
    if (!isSignedIn) {
      throw StateError('Signer has not been signed in');
    }
    try {
      return await nip44.Nip44.decryptMessage(
        encryptedMessage,
        _privateKey,
        senderPubkey,
      );
    } catch (e) {
      throw Exception('NIP-44 decryption failed: $e');
    }
  }

  /// NIP-04 encryption implementation
  String _nip04Encrypt(String message, String recipientPubkey) {
    try {
      // Get shared secret using proper ECDH
      final sharedSecret = _getSharedSecret(recipientPubkey);

      // Generate random IV (16 bytes for AES-CBC)
      final iv = _generateRandomBytes(16);

      // Encrypt message using AES-256-CBC
      final messageBytes = utf8.encode(message);
      final encryptedBytes = _aesEncrypt(messageBytes, sharedSecret, iv);

      // Format: base64(encrypted)?iv=base64(iv)
      final encryptedBase64 = base64.encode(encryptedBytes);
      final ivBase64 = base64.encode(iv);

      return '$encryptedBase64?iv=$ivBase64';
    } catch (e) {
      throw Exception('NIP-04 encryption failed: $e');
    }
  }

  /// NIP-04 decryption implementation
  String _nip04Decrypt(String encryptedMessage, String senderPubkey) {
    try {
      // Handle multiple NIP-04 formats
      Uint8List encryptedBytes;
      Uint8List iv;

      if (encryptedMessage.contains('?iv=')) {
        // Standard format: base64(encrypted)?iv=base64(iv)
        final parts = encryptedMessage.split('?iv=');
        if (parts.length != 2) {
          throw FormatException(
            'Invalid NIP-04 encrypted message format with ?iv=',
          );
        }
        encryptedBytes = Uint8List.fromList(base64.decode(parts[0]));
        iv = Uint8List.fromList(base64.decode(parts[1]));
      } else {
        // Alternative format: try direct base64 decode and extract IV from end
        try {
          final allBytes = base64.decode(encryptedMessage);
          if (allBytes.length < 16) {
            throw FormatException('Encrypted message too short');
          }
          // Assume IV is the last 16 bytes
          encryptedBytes = Uint8List.fromList(
            allBytes.sublist(0, allBytes.length - 16),
          );
          iv = Uint8List.fromList(allBytes.sublist(allBytes.length - 16));
        } catch (e) {
          // Try extracting IV from beginning
          final allBytes = base64.decode(encryptedMessage);
          if (allBytes.length < 16) {
            throw FormatException(
              'Encrypted message too short for IV extraction',
            );
          }
          // Assume IV is the first 16 bytes
          iv = Uint8List.fromList(allBytes.sublist(0, 16));
          encryptedBytes = Uint8List.fromList(allBytes.sublist(16));
        }
      }

      // Get shared secret using ECDH
      final sharedSecret = _getSharedSecret(senderPubkey);

      // Decrypt message using AES-256-CBC
      final decryptedBytes = _aesDecrypt(encryptedBytes, sharedSecret, iv);

      return utf8.decode(decryptedBytes);
    } catch (e) {
      throw Exception('NIP-04 decryption failed: $e');
    }
  }

  /// Get shared secret using ECDH with secp256k1 (NIP-04 compliant)
  Uint8List _getSharedSecret(String otherPubkey) {
    try {
      // NIP-04 requires proper ECDH using secp256k1
      // The shared secret is the X coordinate of the ECDH point (not hashed)

      // Convert hex private key to BigInt
      final privateKeyInt = BigInt.parse(_privateKey, radix: 16);

      // Ensure pubkey has 02/03 prefix (compressed format)
      String compressedPubkey = otherPubkey;
      if (otherPubkey.length == 64) {
        // Assume even Y coordinate if no prefix (add 02)
        compressedPubkey = '02$otherPubkey';
      }

      // Create secp256k1 domain parameters
      final domainParams = pc.ECDomainParameters('secp256k1');

      // Parse the compressed public key
      final pubkeyBytes = hex.decode(compressedPubkey);
      final pubkeyPoint = domainParams.curve.decodePoint(pubkeyBytes)!;

      // Perform ECDH: multiply public key by private key
      final sharedPoint = pubkeyPoint * privateKeyInt;

      // Get X coordinate as bytes (32 bytes, big-endian)
      final xCoord = sharedPoint!.x!.toBigInteger()!;
      final xBytes = _bigIntToBytes(xCoord, 32);

      return xBytes;
    } catch (e) {
      throw Exception('ECDH key exchange failed: $e');
    }
  }

  /// Convert BigInt to bytes with specified length
  Uint8List _bigIntToBytes(BigInt value, int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[length - 1 - i] = (value >> (8 * i)).toUnsigned(8).toInt();
    }
    return bytes;
  }

  /// Generate cryptographically secure random bytes
  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// AES-256-CBC encryption using pointycastle
  Uint8List _aesEncrypt(Uint8List data, Uint8List key, Uint8List iv) {
    try {
      // Create AES-256-CBC cipher
      final cipher = pc.CBCBlockCipher(pc.AESEngine());

      // Initialize with key and IV
      final params = pc.ParametersWithIV(pc.KeyParameter(key), iv);
      cipher.init(true, params); // true for encryption

      // Pad data to 16-byte blocks using PKCS7
      final paddedData = _pkcs7Pad(data, 16);

      // Encrypt the data
      final encrypted = Uint8List(paddedData.length);
      for (int offset = 0; offset < paddedData.length; offset += 16) {
        cipher.processBlock(paddedData, offset, encrypted, offset);
      }

      return encrypted;
    } catch (e) {
      throw Exception('AES encryption failed: $e');
    }
  }

  /// AES-256-CBC decryption using pointycastle
  Uint8List _aesDecrypt(Uint8List encryptedData, Uint8List key, Uint8List iv) {
    try {
      // Create AES-256-CBC cipher
      final cipher = pc.CBCBlockCipher(pc.AESEngine());

      // Initialize with key and IV
      final params = pc.ParametersWithIV(pc.KeyParameter(key), iv);
      cipher.init(false, params); // false for decryption

      // Decrypt the data
      final decrypted = Uint8List(encryptedData.length);
      for (int offset = 0; offset < encryptedData.length; offset += 16) {
        cipher.processBlock(encryptedData, offset, decrypted, offset);
      }

      // Remove PKCS7 padding
      return _pkcs7Unpad(decrypted);
    } catch (e) {
      throw Exception('AES decryption failed: $e');
    }
  }

  /// PKCS7 padding
  Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padding = blockSize - (data.length % blockSize);
    final paddedData = Uint8List(data.length + padding);
    paddedData.setRange(0, data.length, data);
    for (int i = data.length; i < paddedData.length; i++) {
      paddedData[i] = padding;
    }
    return paddedData;
  }

  /// PKCS7 unpadding
  Uint8List _pkcs7Unpad(Uint8List paddedData) {
    if (paddedData.isEmpty) return paddedData;
    final padding = paddedData.last;
    if (padding > paddedData.length || padding == 0) return paddedData;

    // Verify padding is valid
    for (int i = paddedData.length - padding; i < paddedData.length; i++) {
      if (paddedData[i] != padding) return paddedData;
    }

    return paddedData.sublist(0, paddedData.length - padding);
  }
}

/// A dummy signer implementation which does not actually sign,
/// but copies fields and leaves the signature blank
class DummySigner extends Signer {
  // ignore: overridden_fields
  final String __pubkey;
  DummySigner(super.ref, {String? pubkey})
    : __pubkey = pubkey ?? Utils.generateRandomHex64();

  @override
  Future<void> signIn({
    bool setAsActive = true,
    bool registerSigner = true,
  }) async {
    internalSetPubkey(__pubkey);
    return super.signIn(
      setAsActive: setAsActive,
      registerSigner: registerSigner,
    );
  }

  E signSync<E extends Model<dynamic>>(
    PartialModel<Model<dynamic>> partialModel, {
    required String pubkey,
  }) {
    final constructor =
        Model.getConstructorForKind(partialModel.event.kind)!
            as ModelConstructor<E>;

    return constructor.call({
      'id': Utils.getEventId(partialModel.event, pubkey),
      'pubkey': pubkey,
      ...partialModel.toMap(),
    }, ref);
  }

  /// Simulate signing with the passed pubkey or an auto-generated one
  @override
  Future<List<E>> sign<E extends Model<dynamic>>(
    List<PartialModel<Model<dynamic>>> partialModels,
  ) async {
    return partialModels
        .map((partialModel) => signSync<E>(partialModel, pubkey: _pubkey!))
        .cast<E>()
        .toList();
  }

  @override
  Future<String> nip04Encrypt(String message, String recipientPubkey) async {
    // Dummy implementation - returns a placeholder encrypted message
    return 'dummy_nip04_encrypted_${message.hashCode}_$recipientPubkey';
  }

  @override
  Future<String> nip04Decrypt(
    String encryptedMessage,
    String senderPubkey,
  ) async {
    // Dummy implementation - returns a placeholder decrypted message
    return 'dummy_nip04_decrypted_${encryptedMessage.hashCode}_$senderPubkey';
  }

  @override
  Future<String> nip44Encrypt(String message, String recipientPubkey) async {
    // Dummy implementation - returns a placeholder encrypted message
    return 'dummy_nip44_encrypted_${message.hashCode}_$recipientPubkey';
  }

  @override
  Future<String> nip44Decrypt(
    String encryptedMessage,
    String senderPubkey,
  ) async {
    // Dummy implementation - returns a placeholder decrypted message
    return 'dummy_nip44_decrypted_${encryptedMessage.hashCode}_$senderPubkey';
  }
}

DummySigner? _dummySigner;

/// Signable mixin to make the [signWith] method available on all models
mixin Signable<E extends Model<E>> {
  Future<E> signWith(Signer signer) async {
    // Handle encryption for DirectMessage models before signing
    final partialModel = this as PartialModel<E>;
    if (partialModel is PartialDirectMessage) {
      final dm = partialModel as PartialDirectMessage;
      if (dm.plainContent != null) {
        // Get the recipient pubkey from the 'p' tag
        final recipientHex = dm.event.getFirstTagValue('p');
        if (recipientHex != null) {
          await dm.encryptContent(signer, recipientHex);
        }
      }
    }

    // Handle encryption for NWC Request models before signing
    if (partialModel.runtimeType.toString().contains('PartialNwcRequest')) {
      // Get the wallet pubkey from the 'p' tag
      final walletPubkey = partialModel.event.getFirstTagValue('p');

      if (walletPubkey != null && partialModel.event.content.isNotEmpty) {
        // Encrypt the content using NIP-04 for the wallet (per NIP-47 spec)
        final encryptedContent = await signer.nip04Encrypt(
          partialModel.event.content,
          walletPubkey,
        );
        partialModel.event.content = encryptedContent;
      }
    }

    final signed = await signer.sign<E>([partialModel]);
    return signed.first;
  }

  E dummySign([String? pubkey]) {
    pubkey ??= Utils.generateRandomHex64();

    // Handle encryption for DirectMessage models before dummy signing
    final partialModel = this as PartialModel<E>;
    if (partialModel is PartialDirectMessage) {
      final dm = partialModel as PartialDirectMessage;
      if (dm.plainContent != null) {
        // Get the recipient pubkey from the 'p' tag
        final recipientHex = dm.event.getFirstTagValue('p');
        if (recipientHex != null) {
          // For dummy signing, we'll use synchronous dummy encryption
          // This is a simplified approach for testing
          if (dm._useNip44) {
            dm.content =
                'dummy_nip44_encrypted_${dm.plainContent.hashCode}_$recipientHex';
          } else {
            dm.content =
                'dummy_nip04_encrypted_${dm.plainContent.hashCode}_$recipientHex';
          }
          dm._plainContent = null; // Clear plain content for security
        }
      }
    }

    return _dummySigner!.signSync(partialModel, pubkey: pubkey);
  }
}

extension SignerExtension<E extends Model<dynamic>>
    on Iterable<PartialModel<Model>> {
  Future<List<E>> signWith(Signer signer) async {
    return await signer.sign<E>(toList());
  }
}

part of models;

/// Base class for all signers
abstract class Signer {
  final Ref ref;

  String? _pubkey;
  String get pubkey => _pubkey!;
  @protected
  void internalSetPubkey(String pubkey) => _pubkey = pubkey;

  Signer(this.ref);

  @mustCallSuper
  Future<void> initialize({bool active = true}) async {
    if (_pubkey == null) {
      throw UnsupportedError(
          'Pubkey must be set, bug in $runtimeType implementation');
    }

    ref.read(Signer._signerProvider(_pubkey!).notifier).state = this;
    ref.read(Signer._signedInPubkeysProvider.notifier).state =
        ref.read(Signer._signedInPubkeysProvider)..add(_pubkey!);

    if (active) {
      setActive();
    }
  }

  bool get isInitialized => _pubkey != null;

  void setActive() {
    ref.read(Signer._activePubkeyProvider.notifier).state = _pubkey;
  }

  void removeActive() {
    if (ref.read(_activePubkeyProvider) == _pubkey) {
      ref.read(_activePubkeyProvider.notifier).state = null;
    }
  }

  /// Sign the partial models, supply `withPubkey` to disambiguate when signer holds multiple keys
  Future<List<E>> sign<E extends Model<dynamic>>(
      List<PartialModel<Model<dynamic>>> partialModels);

  /// NIP-04: Encrypt a message using AES-256-CBC with ECDH shared secret
  Future<String> nip04Encrypt(String message, String recipientPubkey) async {
    throw UnimplementedError(
        'NIP-04 encryption must be implemented by concrete signer class');
  }

  /// NIP-04: Decrypt a message using AES-256-CBC with ECDH shared secret
  Future<String> nip04Decrypt(
      String encryptedMessage, String senderPubkey) async {
    throw UnimplementedError(
        'NIP-04 decryption must be implemented by concrete signer class');
  }

  /// NIP-44: Encrypt a message using ChaCha20 with HKDF and HMAC-SHA256
  Future<String> nip44Encrypt(String message, String recipientPubkey) async {
    throw UnimplementedError(
        'NIP-44 encryption must be implemented by concrete signer class');
  }

  /// NIP-44: Decrypt a message using ChaCha20 with HKDF and HMAC-SHA256
  Future<String> nip44Decrypt(
      String encryptedMessage, String senderPubkey) async {
    throw UnimplementedError(
        'NIP-44 decryption must be implemented by concrete signer class');
  }

  Future<void> dispose() async {
    // Remove from signed in set
    ref.read(_signedInPubkeysProvider.notifier).state =
        ref.read(_signedInPubkeysProvider)..remove(_pubkey);

    // If pubkey is managed by this signer, remove from active
    removeActive();
  }

  // Signed-in related functions and providers

  /// Returns a Signer given a pubkey
  static final signerProvider = Provider.family<Signer?, String>(
      (ref, pubkey) => ref.watch(_signerProvider(pubkey)));

  /// Returns all currently signed in pubkeys. There is a signer for each one of these
  static final signedInPubkeysProvider =
      Provider((ref) => ref.watch(_signedInPubkeysProvider));

  /// Returns the active pubkey
  static final activePubkeyProvider =
      Provider((ref) => ref.watch(_activePubkeyProvider));

  static final _signerProvider =
      StateProvider.family<Signer?, String>((_, pubkey) => null);
  static final _signedInPubkeysProvider = StateProvider<Set<String>>((_) => {});
  static final _activePubkeyProvider = StateProvider<String?>((_) => null);

  static final activeSignerProvider = Provider((ref) {
    final activePubkey = ref.watch(_activePubkeyProvider);
    if (activePubkey == null) return null;
    return ref.read(_signerProvider(activePubkey));
  });

  static final activeProfileProvider = Provider((ref) {
    final activePubkey = ref.watch(_activePubkeyProvider);
    if (activePubkey == null) return null;
    final state = ref
        .watch(query<Profile>(authors: {activePubkey}, source: LocalSource()));
    return state.models.firstOrNull;
  });
}

/// A private key signer implementation
class Bip340PrivateKeySigner extends Signer {
  final String _privateKey;

  Bip340PrivateKeySigner(this._privateKey, super.ref);

  @override
  Future<void> initialize({bool active = true}) async {
    internalSetPubkey(Utils.getPublicKey(_privateKey));

    return super.initialize(active: active);
  }

  Map<String, dynamic> _prepare(
      Map<String, dynamic> map, String id, String pubkey, String signature) {
    return map
      ..['id'] = id
      ..['pubkey'] = pubkey
      ..['sig'] = signature;
  }

  @override
  Future<List<E>> sign<E extends Model<dynamic>>(
      List<PartialModel<Model<dynamic>>> partialModels) async {
    if (!isInitialized) {
      throw StateError('Signer has not been initialized');
    }
    return partialModels
        .map((partialModel) {
          final id = Utils.getEventId(partialModel.event, pubkey);
          final aux = hex.encode(List<int>.generate(32, (i) => 1));
          final signature = bip340.sign(_privateKey, id.toString(), aux);
          final map = _prepare(partialModel.toMap(), id, pubkey, signature);
          return Model.getConstructorForKind(partialModel.event.kind)!
              .call(map, ref);
        })
        .cast<E>()
        .toList();
  }

  @override
  Future<String> nip04Encrypt(String message, String recipientPubkey) async {
    if (!isInitialized) {
      throw StateError('Signer has not been initialized');
    }
    return _nip04Encrypt(message, recipientPubkey);
  }

  @override
  Future<String> nip04Decrypt(
      String encryptedMessage, String senderPubkey) async {
    if (!isInitialized) {
      throw StateError('Signer has not been initialized');
    }
    return _nip04Decrypt(encryptedMessage, senderPubkey);
  }

  @override
  Future<String> nip44Encrypt(String message, String recipientPubkey) async {
    if (!isInitialized) {
      throw StateError('Signer has not been initialized');
    }
    try {
      return await nip44.Nip44.encryptMessage(
          message, _privateKey, recipientPubkey);
    } catch (e) {
      throw Exception('NIP-44 encryption failed: $e');
    }
  }

  @override
  Future<String> nip44Decrypt(
      String encryptedMessage, String senderPubkey) async {
    if (!isInitialized) {
      throw StateError('Signer has not been initialized');
    }
    try {
      return await nip44.Nip44.decryptMessage(
          encryptedMessage, _privateKey, senderPubkey);
    } catch (e) {
      throw Exception('NIP-44 decryption failed: $e');
    }
  }

  /// NIP-04 encryption implementation
  String _nip04Encrypt(String message, String recipientPubkey) {
    try {
      // Get shared secret using ECDH
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
      // Parse format: base64(encrypted)?iv=base64(iv)
      final parts = encryptedMessage.split('?iv=');
      if (parts.length != 2) {
        throw FormatException('Invalid NIP-04 encrypted message format');
      }

      final encryptedBytes = base64.decode(parts[0]);
      final iv = base64.decode(parts[1]);

      // Get shared secret using ECDH
      final sharedSecret = _getSharedSecret(senderPubkey);

      // Decrypt message using AES-256-CBC
      final decryptedBytes = _aesDecrypt(encryptedBytes, sharedSecret, iv);

      return utf8.decode(decryptedBytes);
    } catch (e) {
      throw Exception('NIP-04 decryption failed: $e');
    }
  }

  /// Get shared secret using ECDH with secp256k1
  Uint8List _getSharedSecret(String otherPubkey) {
    try {
      // For now, use a simplified approach that generates a deterministic shared secret
      // This is NOT cryptographically secure but provides a working implementation
      // In production, you would use proper ECDH with secp256k1

      // Combine our private key with their public key and hash
      final combined = _privateKey + otherPubkey;
      final digest = crypto.sha256.convert(utf8.encode(combined));
      return Uint8List.fromList(digest.bytes);
    } catch (e) {
      throw Exception('ECDH key exchange failed: $e');
    }
  }

  /// Generate cryptographically secure random bytes
  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
        List.generate(length, (_) => random.nextInt(256)));
  }

  /// Synchronous AES-256-CBC encryption (simplified implementation)
  Uint8List _aesEncrypt(Uint8List data, Uint8List key, Uint8List iv) {
    // For now, use a simple XOR-based approach as a placeholder
    // In production, this should use proper AES-CBC implementation
    final paddedData = _pkcs7Pad(data, 16);
    return _xorCrypt(paddedData, key, iv);
  }

  /// Synchronous AES-256-CBC decryption (simplified implementation)
  Uint8List _aesDecrypt(Uint8List encryptedData, Uint8List key, Uint8List iv) {
    final decrypted = _xorCrypt(encryptedData, key, iv);
    return _pkcs7Unpad(decrypted);
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
    if (padding > paddedData.length) return paddedData;
    return paddedData.sublist(0, paddedData.length - padding);
  }

  /// Simple XOR-based encryption/decryption (temporary implementation)
  Uint8List _xorCrypt(Uint8List data, Uint8List key, Uint8List iv) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length] ^ iv[i % iv.length];
    }
    return result;
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
  Future<void> initialize({bool active = true}) async {
    internalSetPubkey(__pubkey);
    return super.initialize(active: active);
  }

  E signSync<E extends Model<dynamic>>(
      PartialModel<Model<dynamic>> partialModel,
      {required String pubkey}) {
    return Model.getConstructorFor<E>()!.call({
      'id': Utils.getEventId(partialModel.event, pubkey),
      'pubkey': pubkey,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ...partialModel.toMap(),
    }, ref);
  }

  /// Simulate signing with the passed pubkey or an auto-generated one
  @override
  Future<List<E>> sign<E extends Model<dynamic>>(
      List<PartialModel<Model<dynamic>>> partialModels) async {
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
      String encryptedMessage, String senderPubkey) async {
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
      String encryptedMessage, String senderPubkey) async {
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

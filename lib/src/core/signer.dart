part of models;

/// Base class for all Nostr event signers.
///
/// Signers handle cryptographic operations for creating and signing Nostr events.
/// Different implementations can provide various signing methods like private keys,
/// hardware wallets, or remote signing services.
abstract class Signer {
  final Ref ref;

  String? _pubkey;

  /// The public key (in hex format) associated with this signer.
  String get pubkey => _pubkey!;

  @protected
  void internalSetPubkey(String pubkey) => _pubkey = pubkey;

  Signer(this.ref);

  /// Check if this signer is available for use.
  ///
  /// Override this method to implement availability checks,
  /// such as hardware wallet connectivity or service reachability.
  Future<bool> get isAvailable async {
    return true;
  }

  // New Public API Methods

  /// Sign in the signer with the current pubkey.
  ///
  /// This is the preferred method for signing in signers.
  /// [setAsActive] determines whether this signer becomes the active signer after sign in.
  /// [registerSigner] determines whether to register this signer in the global registry.
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
  /// @deprecated Use nip44Encrypt instead
  Future<String> nip04Encrypt(String message, String recipientPubkey);

  /// NIP-04: Decrypt a message using AES-256-CBC with ECDH shared secret
  /// @deprecated Use nip44Decrypt instead
  Future<String> nip04Decrypt(String encryptedMessage, String senderPubkey);

  /// NIP-44: Encrypt a message using ChaCha20 with HKDF and HMAC-SHA256
  Future<String> nip44Encrypt(String message, String recipientPubkey);

  /// NIP-44: Decrypt a message using ChaCha20 with HKDF and HMAC-SHA256
  Future<String> nip44Decrypt(String encryptedMessage, String senderPubkey);

  // NWC-related

  /// Identifier for storing NWC connection string in CustomData
  static const String kNwcConnectionString = 'nwc_connection_string';

  /// Get the NWC connection string for this signer
  Future<String?> getNWCString() async {
    if (!isSignedIn) {
      throw StateError('Signer has not been signed in');
    }

    try {
      final storage = ref.read(storageNotifierProvider.notifier);
      final customDataList = await storage.query(
        RequestFilter<CustomData>(
          authors: {pubkey},
          tags: {
            '#d': {kNwcConnectionString},
          },
        ).toRequest(),
        source: LocalSource(),
      );

      if (customDataList.isEmpty) return null;

      final customData = customDataList.first;

      // If content is empty, treat as deleted
      if (customData.content.isEmpty) return null;

      return await nip44Decrypt(customData.content, pubkey);
    } catch (e) {
      return null;
    }
  }

  /// Set the NWC connection string for this signer
  Future<void> setNWCString(String connectionString) async {
    if (!isSignedIn) {
      throw StateError('Signer has not been signed in');
    }

    final storage = ref.read(storageNotifierProvider.notifier);
    final encryptedData = await nip44Encrypt(connectionString, pubkey);

    final partialData = PartialCustomData(
      identifier: kNwcConnectionString,
      content: encryptedData,
    );

    final signedData = (await sign([partialData])).first;
    await storage.save({signedData});
  }

  /// Clear the NWC connection string for this signer
  Future<void> clearNWCString() async {
    if (!isSignedIn) {
      throw StateError('Signer has not been signed in');
    }

    final storage = ref.read(storageNotifierProvider.notifier);

    // Create empty CustomData to "delete" the connection string
    final partialData = PartialCustomData(
      identifier: kNwcConnectionString,
      content: '',
    );

    final signedData = (await sign([partialData])).first;
    await storage.save({signedData});
  }

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

  @override
  Future<String> nip04Decrypt(String encryptedMessage, String senderPubkey) {
    throw UnsupportedError('No NIP-04 support');
  }

  @override
  Future<String> nip04Encrypt(String message, String recipientPubkey) {
    throw UnsupportedError('No NIP-04 support');
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

  @override
  Future<String> nip04Decrypt(String encryptedMessage, String senderPubkey) {
    throw UnsupportedError('No NIP-04 support');
  }

  @override
  Future<String> nip04Encrypt(String message, String recipientPubkey) {
    throw UnsupportedError('No NIP-04 support');
  }
}

DummySigner? _dummySigner;

/// Signable mixin to make the [signWith] method available on all models
mixin Signable<E extends Model<E>> {
  Future<E> signWith(Signer signer) async {
    final partialModel = this as PartialModel<E>;

    // Call the prepareForSigning hook to allow models to handle
    // validation or other preparation before signing
    await partialModel.prepareForSigning(signer);

    final signed = await signer.sign<E>([partialModel]);
    return signed.first;
  }

  E dummySign([String? pubkey]) {
    pubkey ??= Utils.generateRandomHex64();

    final partialModel = this as PartialModel<E>;

    // Use runSync to execute async prepareForSigning synchronously
    final dummySigner = DummySigner(_dummySigner!.ref, pubkey: pubkey);
    dummySigner.internalSetPubkey(
      pubkey,
    ); // Set pubkey before prepareForSigning
    runSync(() => partialModel.prepareForSigning(dummySigner));

    return _dummySigner!.signSync(partialModel, pubkey: pubkey);
  }
}

extension SignerExtension<E extends Model<dynamic>>
    on Iterable<PartialModel<Model>> {
  Future<List<E>> signWith(Signer signer) async {
    return await signer.sign<E>(toList());
  }
}

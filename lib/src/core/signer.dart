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

  // TODO: Implement nip04Encrypt, nip04Decrypt, nip44Encrypt, nip44Decrypt

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
}

DummySigner? _dummySigner;

/// Signable mixin to make the [signWith] method available on all models
mixin Signable<E extends Model<E>> {
  Future<E> signWith(Signer signer) async {
    final signed = await signer.sign<E>([this as PartialModel<E>]);
    return signed.first;
  }

  E dummySign([String? pubkey]) {
    pubkey ??= Utils.generateRandomHex64();
    return _dummySigner!.signSync(this as PartialModel<E>, pubkey: pubkey);
  }
}

extension SignerExtension<E extends Model<dynamic>>
    on Iterable<PartialModel<Model>> {
  Future<List<E>> signWith(Signer signer) async {
    return await signer.sign<E>(toList());
  }
}

part of models;

/// Base class for all signers
abstract class Signer {
  final Ref ref;

  Signer(this.ref);

  Future<Signer> initialize();
  Future<String?> getPublicKey();

  /// Sign the partial model, supply `withPubkey` to disambiguate when signer holds multiple keys
  Future<E> sign<E extends Model<E>>(PartialModel<E> partialModel,
      {String? withPubkey});

  /// To be used by signer implementations to indicate a "sign in" by a new pubkey
  @protected
  void addSignedInPubkey(String pubkey) {
    final n = ref.read(Profile._signedInPubkeysProvider.notifier);
    n.state = {...n.state, pubkey};
  }
}

/// A private key signer implementation
class Bip340PrivateKeySigner extends Signer {
  final String privateKey;
  Bip340PrivateKeySigner(this.privateKey, super.ref);

  @override
  Future<Signer> initialize() async {
    return this;
  }

  @override
  Future<String?> getPublicKey() async {
    final pubkey = Utils.getPublicKey(privateKey);
    addSignedInPubkey(pubkey);
    return pubkey;
  }

  Map<String, dynamic> _prepare(
      Map<String, dynamic> map, String id, String pubkey, String signature) {
    return map
      ..['id'] = id
      ..['pubkey'] = pubkey
      ..['sig'] = signature;
  }

  @override
  Future<E> sign<E extends Model<E>>(PartialModel<E> partialModel,
      {String? withPubkey}) async {
    final pubkey = (await getPublicKey())!;
    final id = Utils.getEventId(partialModel.event, pubkey);
    final aux = hex.encode(List<int>.generate(32, (i) => 1));
    final signature = bip340.sign(privateKey, id.toString(), aux);
    final map = _prepare(partialModel.toMap(), id, pubkey, signature);
    return Model.getConstructorFor<E>()!.call(map, ref);
  }
}

/// A dummy signer implementation which does not actually sign,
/// but copies fields and leaves the signature blank
class DummySigner extends Signer {
  DummySigner(super.ref);
  String? pubkey;

  @override
  Future<String?> getPublicKey() async {
    return pubkey;
  }

  @override
  Future<Signer> initialize() async {
    return this;
  }

  E signSync<E extends Model<E>>(PartialModel<E> partialModel,
      {String? withPubkey}) {
    pubkey = withPubkey ?? Utils.generateRandomHex64();
    return Model.getConstructorFor<E>()!.call({
      'id': Utils.getEventId(partialModel.event, pubkey!),
      'pubkey': pubkey,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ...partialModel.toMap(),
    }, ref);
  }

  /// Simulate signing with the passed pubkey or an auto-generated one
  @override
  Future<E> sign<E extends Model<E>>(PartialModel<E> partialModel,
      {String? withPubkey}) async {
    return signSync(partialModel, withPubkey: withPubkey);
  }
}

DummySigner? _dummySigner;

/// Signable mixin to make the [signWith] method available on all models
mixin Signable<E extends Model<E>> {
  Future<E> signWith(Signer signer, {String? withPubkey}) {
    return signer.sign<E>(this as PartialModel<E>, withPubkey: withPubkey);
  }

  E dummySign([String? withPubkey]) =>
      _dummySigner!.signSync(this as PartialModel<E>, withPubkey: withPubkey);
}

part of models;

/// Base class for all signers
abstract class Signer {
  final Ref ref;

  Signer(this.ref);

  Future<Signer> initialize();
  Future<String> getPublicKey();

  /// Sign the partial models, supply `withPubkey` to disambiguate when signer holds multiple keys
  Future<List<E>> sign<E extends Model<dynamic>>(
      List<PartialModel<dynamic>> partialModels,
      {String? withPubkey});

  /// To be used by signer implementations to indicate a "sign in" by a new pubkey
  @protected
  void addSignedInPubkey(String pubkey) {
    final n = ref.read(Profile._signedInPubkeysProvider.notifier);
    n.state = {...n.state, pubkey};
  }

  // TODO: Implement nip04Encrypt, nip04Decrypt, nip44Encrypt, nip44Decrypt

  Future<void> dispose() async {}
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
  Future<String> getPublicKey() async {
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
  Future<List<E>> sign<E extends Model<dynamic>>(
      List<PartialModel<dynamic>> partialModels,
      {String? withPubkey}) async {
    final pubkey = await getPublicKey();
    return partialModels
        .map((partialModel) {
          final id = Utils.getEventId(partialModel.event, pubkey);
          final aux = hex.encode(List<int>.generate(32, (i) => 1));
          final signature = bip340.sign(privateKey, id.toString(), aux);
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
  DummySigner(super.ref);
  var pubkey = Utils.generateRandomHex64();

  @override
  Future<String> getPublicKey() async {
    return pubkey;
  }

  @override
  Future<Signer> initialize() async {
    return this;
  }

  E signSync<E extends Model<dynamic>>(PartialModel<dynamic> partialModel,
      {String? withPubkey}) {
    if (withPubkey != null) {
      pubkey = withPubkey;
    }
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
      List<PartialModel<dynamic>> partialModels,
      {String? withPubkey}) async {
    return partialModels
        .map((partialModel) {
          return signSync(partialModel, withPubkey: withPubkey);
        })
        .cast<E>()
        .toList();
  }
}

DummySigner? _dummySigner;

/// Signable mixin to make the [signWith] method available on all models
mixin Signable<E extends Model<E>> {
  Future<E> signWith(Signer signer, {String? withPubkey}) async {
    final signed =
        await signer.sign<E>([this as PartialModel<E>], withPubkey: withPubkey);
    return signed.first;
  }

  E dummySign([String? withPubkey]) =>
      _dummySigner!.signSync(this as PartialModel<E>, withPubkey: withPubkey);
}

extension SignerExtension<E extends Model<dynamic>> on Iterable<PartialModel> {
  Future<List<Model>> signWith(Signer signer, {String? withPubkey}) async {
    return await signer.sign(toList(), withPubkey: withPubkey);
  }
}

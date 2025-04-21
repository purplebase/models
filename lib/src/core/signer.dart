part of models;

abstract class Signer {
  final Ref ref;
  static final _signedInPubkeysProvider = StateProvider((ref) => <String>{});

  Signer(this.ref);

  Future<Signer> initialize();
  Future<String?> getPublicKey();

  /// Sign the partial model, supply `withPubkey` to disambiguate when signer holds multiple keys
  Future<E> sign<E extends Model<E>>(PartialModel<E> partialModel,
      {String? withPubkey});

  @protected
  void addSignedInPubkey(String pubkey) {
    final n = ref.read(_signedInPubkeysProvider.notifier);
    n.state = {...n.state, pubkey};
  }
}

class Bip340PrivateKeySigner extends Signer {
  final String privateKey;
  Bip340PrivateKeySigner(this.privateKey, super.ref);

  @override
  Future<Signer> initialize() async {
    return this;
  }

  @override
  Future<String?> getPublicKey() async {
    final pubkey = Profile.getPublicKey(privateKey);
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
    final id = partialModel.getEventId(pubkey);
    final aux = hex.encode(List<int>.generate(32, (i) => 1));
    final signature = bip340.sign(privateKey, id.toString(), aux);
    final map = _prepare(partialModel.toMap(), id, pubkey, signature);
    return Model.getConstructorFor<E>()!.call(map, ref);
  }
}

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
    addSignedInPubkey(pubkey!);
    return Model.getConstructorFor<E>()!.call({
      'id': partialModel.getEventId(pubkey!),
      'pubkey': pubkey,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ...partialModel.toMap(),
    }, ref);
  }

  @override
  Future<E> sign<E extends Model<E>>(PartialModel<E> partialModel,
      {String? withPubkey}) async {
    return signSync(partialModel, withPubkey: withPubkey);
  }
}

final signedInProfilesProvider = Provider((ref) {
  final pubkeys = ref.watch(Signer._signedInPubkeysProvider);
  return ref
      .read(storageNotifierProvider.notifier)
      .querySync(RequestFilter<Profile>(authors: pubkeys));
});

DummySigner? _dummySigner;

mixin Signable<E extends Model<E>> {
  Future<E> signWith(Signer signer, {String? withPubkey}) {
    return signer.sign<E>(this as PartialModel<E>, withPubkey: withPubkey);
  }

  E dummySign([String? withPubkey]) =>
      _dummySigner!.signSync(this as PartialModel<E>, withPubkey: withPubkey);
}

final initializationProvider =
    FutureProvider.family<bool, StorageConfiguration>((ref, config) async {
  _dummySigner = DummySigner(ref);
  await ref.read(storageNotifierProvider.notifier).initialize(config);
  return true;
});

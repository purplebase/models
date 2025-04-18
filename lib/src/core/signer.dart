part of models;

mixin Signable<E extends Model<E>> {
  Future<E> signWith(Signer signer, {String? withPubkey}) {
    return signer.sign<E>(this as PartialModel<E>, withPubkey: withPubkey);
  }

  E dummySign([String? withPubkey]) =>
      _dummySigner.signSync(this as PartialModel<E>, withPubkey: withPubkey);
}

// Needs to be here because of Signer._ref
final initializationProvider =
    FutureProvider.family<bool, StorageConfiguration>((ref, config) async {
  // Initialize a private ref exclusive for signers
  Signer._ref = ref;
  await ref.read(storageNotifierProvider.notifier).initialize(config);
  return true;
});

abstract class Signer {
  static late Ref _ref;
  Future<Signer> initialize();
  Future<String?> getPublicKey();

  /// Sign the partial model, supply `withPubkey` to disambiguate when signer holds multiple keys
  Future<E> sign<E extends Model<E>>(PartialModel<E> partialModel,
      {String? withPubkey});
}

class Bip340PrivateKeySigner extends Signer {
  final String privateKey;
  Bip340PrivateKeySigner(this.privateKey);

  @override
  Future<Signer> initialize() async {
    return this;
  }

  @override
  Future<String?> getPublicKey() async {
    return Profile.getPublicKey(privateKey);
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
    final pubkey = Profile.getPublicKey(privateKey);
    final id = partialModel.getEventId(pubkey);
    final aux = hex.encode(List<int>.generate(32, (i) => 1));
    final signature = bip340.sign(privateKey, id.toString(), aux);
    final map = _prepare(partialModel.toMap(), id, pubkey, signature);
    return Model.getConstructorFor<E>()!.call(map, Signer._ref);
  }
}

class DummySigner extends Signer {
  @override
  Future<String?> getPublicKey() async {
    return null;
  }

  @override
  Future<Signer> initialize() async {
    return this;
  }

  E signSync<E extends Model<E>>(PartialModel<E> partialModel,
      {String? withPubkey}) {
    final pubkey = withPubkey ?? generate64Hex();
    return Model.getConstructorFor<E>()!.call({
      'id': partialModel.getEventId(pubkey),
      'pubkey': pubkey,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ...partialModel.toMap(),
    }, Signer._ref);
  }

  @override
  Future<E> sign<E extends Model<E>>(PartialModel<E> partialModel,
      {String? withPubkey}) async {
    return signSync(partialModel, withPubkey: withPubkey);
  }
}

String generate64Hex() {
  // Generate 32 random bytes; 32 bytes * 2 hex digits per byte = 64 hex characters
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));

  // Convert the bytes to a hex string, making sure each byte is represented with two digits
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');

  return hex;
}

final _dummySigner = DummySigner();

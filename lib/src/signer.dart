import 'package:bip340/bip340.dart' as bip340;
import 'package:convert/convert.dart';
import 'package:models/src/event.dart';
import 'package:models/src/utils.dart';
import 'package:riverpod/riverpod.dart';

mixin Signable<E extends Event<E>> {
  Future<E> signWith(Signer signer, {String? withPubkey}) {
    return signer.sign<E>(this as PartialEvent<E>, withPubkey: withPubkey);
  }
}

final initializationProvider = FutureProvider<bool>((ref) async {
  // Initialize a private ref exclusive for signers
  Signer._ref = ref;
  return true;
});

abstract class Signer {
  static late Ref _ref;
  Future<Signer> initialize();
  Future<String?> getPublicKey();

  /// Sign the partial event, supply `withPubkey` to disambiguate when signer holds multiple keys
  Future<E> sign<E extends Event<E>>(PartialEvent<E> partialEvent,
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
    return BaseUtil.getPublicKey(privateKey);
  }

  Map<String, dynamic> _prepare(
      Map<String, dynamic> map, String id, String pubkey, String signature,
      {DateTime? createdAt}) {
    return map
      ..['id'] = id
      ..['pubkey'] = pubkey
      ..['sig'] = signature
      ..['created_at'] = createdAt ?? map['created_at'] ?? DateTime.now();
  }

  @override
  Future<E> sign<E extends Event<E>>(PartialEvent<E> partialEvent,
      {String? withPubkey}) async {
    final pubkey = BaseUtil.getPublicKey(privateKey);
    final id = partialEvent.getEventId(pubkey);
    // TODO: Should aux be random? random.nextInt(256)
    final aux = hex.encode(List<int>.generate(32, (i) => 1));
    final signature = bip340.sign(privateKey, id.toString(), aux);
    final map = _prepare(partialEvent.toMap(), id, pubkey, signature);
    return Event.getConstructor<E>()!.call(map, Signer._ref);
  }
}

class DummySigner extends Signer {
  final _pubkey =
      '8f1536c05fa9c3f441f1a369b661f3cb1072f418a876d153edf3fc6eec41794c';

  @override
  Future<String?> getPublicKey() async {
    return _pubkey;
  }

  @override
  Future<Signer> initialize() async {
    return this;
  }

  @override
  Future<E> sign<E extends Event<E>>(PartialEvent<E> partialEvent,
      {String? withPubkey}) async {
    return Event.getConstructor<E>()!.call({
      'id': partialEvent.getEventId(withPubkey ?? _pubkey),
      'pubkey': withPubkey ?? _pubkey,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ...partialEvent.toMap(),
    }, Signer._ref);
  }
}

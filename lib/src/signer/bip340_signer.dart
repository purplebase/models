import 'package:bip340/bip340.dart' as bip340;
import 'package:convert/convert.dart';

import '../core/model.dart';
import '../nip44/nip44.dart' as nip44;
import '../nip04/nip04.dart';
import '../utils/utils.dart';
import '../utils/extensions.dart';
import 'signer.dart';

/// A private key signer implementation.
class Bip340PrivateKeySigner extends Signer {
  final String _privateKey;

  Bip340PrivateKeySigner(String privateKey, super.ref)
      : _privateKey = privateKey.decodeShareable();

  @override
  Future<void> initialize() async {
    internalSetPubkey(Utils.derivePublicKey(_privateKey));
  }

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
          return Model.getConstructorForKind(partialModel.event.kind)!
              .call(map, ref);
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
  Future<String> nip04Decrypt(
      String encryptedMessage, String senderPubkey) async {
    if (!isSignedIn) {
      throw StateError('Signer has not been signed in');
    }
    try {
      return Nip04.decrypt(encryptedMessage, _privateKey, senderPubkey);
    } catch (e) {
      throw Exception('NIP-04 decryption failed: $e');
    }
  }

  @override
  Future<String> nip04Encrypt(String message, String recipientPubkey) async {
    if (!isSignedIn) {
      throw StateError('Signer has not been signed in');
    }
    try {
      return Nip04.encrypt(message, _privateKey, recipientPubkey);
    } catch (e) {
      throw Exception('NIP-04 encryption failed: $e');
    }
  }
}

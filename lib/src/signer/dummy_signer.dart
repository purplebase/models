import '../core/model.dart';
import '../core/types.dart';
import '../utils/utils.dart';
import 'signer.dart';

class DummySigner extends Signer {
  final String _internalPubkey;

  DummySigner(super.ref, {String? pubkey})
      : _internalPubkey = pubkey ?? Utils.generateRandomHex64();

  @override
  Future<void> initialize() async {
    internalSetPubkey(_internalPubkey);
  }

  @override
  Future<void> signIn({
    bool setAsActive = true,
    bool registerSigner = true,
  }) async {
    internalSetPubkey(_internalPubkey);
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

  @override
  Future<List<E>> sign<E extends Model<dynamic>>(
    List<PartialModel<Model<dynamic>>> partialModels,
  ) async {
    if (!isSignedIn) {
      throw StateError('Signer has not been signed in');
    }
    return partialModels
        .map((partialModel) => signSync<E>(partialModel, pubkey: pubkey))
        .cast<E>()
        .toList();
  }

  @override
  Future<String> nip44Encrypt(String message, String recipientPubkey) async {
    return 'dummy_nip44_encrypted_${message.hashCode}_$recipientPubkey';
  }

  @override
  Future<String> nip44Decrypt(
    String encryptedMessage,
    String senderPubkey,
  ) async {
    return 'dummy_nip44_decrypted_${encryptedMessage.hashCode}_$senderPubkey';
  }

  @override
  Future<String> nip04Decrypt(
    String encryptedMessage,
    String senderPubkey,
  ) async {
    return 'dummy_nip04_decrypted_${encryptedMessage.hashCode}_$senderPubkey';
  }

  @override
  Future<String> nip04Encrypt(String message, String recipientPubkey) async {
    return 'dummy_nip04_encrypted_${message.hashCode}_$recipientPubkey';
  }
}

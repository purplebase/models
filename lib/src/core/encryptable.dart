import 'dart:convert';

import 'model.dart';
import '../signer/signer.dart';

/// Mixin for models that support encrypted content in the `content` field.
mixin EncryptableModel<E extends Model<E>> on Model<E> {
  /// Get the pubkey used for encryption.
  String getEncryptionPubkey();

  /// Whether to use NIP-04 encryption (always false, NIP-44 only).
  bool get useNip04 => false;

  /// Get the encrypted content.
  String get content => event.content;
}

/// Mixin for partial models that support encrypted content.
mixin EncryptablePartialModel<E extends Model<E>> on PartialModel<E> {
  /// Get the pubkey to use for encryption.
  String getEncryptionPubkey(Signer signer);

  /// Whether to use NIP-04 encryption.
  bool get useNip04 => false;

  /// Set content (stored as plaintext until signing).
  void setContent(dynamic data) {
    event.content = data is String ? data : jsonEncode(data);
  }

  /// Get the content.
  String get content => event.content;

  /// Clear the content.
  void clearContent() {
    event.content = '';
  }

  /// Encrypt content before signing.
  @override
  Future<void> prepareForSigning(Signer signer) async {
    final encPubkey = getEncryptionPubkey(signer);

    if (event.content.isNotEmpty && !_isAlreadyEncrypted(event.content)) {
      if (useNip04) {
        event.content = await signer.nip04Encrypt(event.content, encPubkey);
      } else {
        event.content = await signer.nip44Encrypt(event.content, encPubkey);
      }
    }

    await super.prepareForSigning(signer);
  }

  bool _isAlreadyEncrypted(String content) {
    if (content.contains('?iv=')) return true;
    if (content.length > 50 && content.startsWith('A')) {
      final base64Pattern = RegExp(r'^[A-Za-z0-9+/]+=*$');
      return base64Pattern.hasMatch(content);
    }
    return false;
  }
}

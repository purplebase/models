import 'dart:convert';

import 'package:riverpod/riverpod.dart';

import 'model.dart';
import '../signer/signer.dart';

/// Mixin for immutable models whose `event.content` is NIP-44/NIP-04 encrypted.
mixin EncryptableModel<E extends Model<E>> on Model<E> {
  static const _cacheKey = '_decrypted';

  /// The decrypted plaintext content, or `null` if not yet decrypted.
  String? get plaintext => event.metadata[_cacheKey] as String?;

  /// Whether [prepareAfterLoading] has successfully decrypted the content.
  bool get isDecrypted => event.metadata.containsKey(_cacheKey);

  /// The pubkey used when the content was encrypted.
  String getEncryptionPubkey();

  /// Whether to use NIP-04 instead of NIP-44 for encryption/decryption.
  bool get useNip04 => false;

  /// The raw encrypted content field from the event.
  String get content => event.content;

  @override
  Future<void> prepareAfterLoading(Ref ref) async {
    if (isDecrypted || event.content.isEmpty) return;

    final encPubkey = getEncryptionPubkey();
    Signer? signer;
    String decryptionPubkey;

    if (encPubkey == event.pubkey) {
      signer = ref.read(Signer.signerProvider(event.pubkey));
      decryptionPubkey = event.pubkey;
    } else {
      signer = ref.read(Signer.signerProvider(event.pubkey));
      if (signer != null) {
        decryptionPubkey = encPubkey;
      } else {
        signer = ref.read(Signer.signerProvider(encPubkey));
        decryptionPubkey = event.pubkey;
      }
    }

    if (signer == null) return;

    try {
      final decrypted = useNip04
          ? await signer.nip04Decrypt(event.content, decryptionPubkey)
          : await signer.nip44Decrypt(event.content, decryptionPubkey);
      event.metadata[_cacheKey] = decrypted;
    } catch (_) {
      // Decryption is best-effort; getters keep their encrypted fallback.
    }
  }

  @override
  Map<String, dynamic> toMap() {
    final raw = super.toMap();
    final metadata = raw['metadata'];
    if (metadata is! Map || !metadata.containsKey(_cacheKey)) return raw;

    final cleaned = Map<String, dynamic>.from(metadata)..remove(_cacheKey);
    final result = Map<String, dynamic>.from(raw);
    if (cleaned.isEmpty) {
      result.remove('metadata');
    } else {
      result['metadata'] = cleaned;
    }
    return result;
  }

  @override
  P toPartial<P extends PartialModel<dynamic>>() {
    final cached = plaintext;
    if (cached == null) return super.toPartial<P>();

    event.metadata['_plaintext'] = cached;
    try {
      return super.toPartial<P>();
    } finally {
      event.metadata.remove('_plaintext');
    }
  }
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

part of models;

/// A direct message event (kind 4) for private communication between users.
///
/// Direct messages are encrypted using NIP-04 and can only be decrypted by
/// the sender and recipient. They provide private, peer-to-peer communication.
class DirectMessage extends RegularModel<DirectMessage> {
  DirectMessage.fromMap(super.map, super.ref) : super.fromMap();

  /// The recipient's npub (Bech32-encoded public key)
  String get receiver => Utils.encodeShareableFromString(
    event.getFirstTagValue('p')!,
    type: 'npub',
  );

  /// Get decrypted content using the active signer
  /// Since decryption is now async, this returns the raw content.
  /// Use [decryptContent()] for actual decryption.
  String get content {
    return event.content;
  }

  /// Decrypt the content using the active signer
  Future<String> decryptContent() async {
    final activeSigner = ref.read(Signer.activeSignerProvider);
    if (activeSigner == null) {
      // If no signer is available, return raw content (might be encrypted)
      return event.content;
    }

    // Determine the other party's public key for decryption
    // If we are the sender, decrypt using recipient's key
    // If we are the recipient, decrypt using sender's key
    final otherPubkey = activeSigner.pubkey == event.pubkey
        ? event.getFirstTagValue('p')! // We are sender, use recipient's key
        : event.pubkey; // We are recipient, use sender's key

    // Try to decrypt the content
    try {
      // First try NIP-44 decryption (more secure, newer standard)
      // NIP-44 messages start with 'A' in base64 and don't contain '?'
      if (event.content.startsWith('A') && !event.content.contains('?')) {
        return await activeSigner.nip44Decrypt(event.content, otherPubkey);
      } else {
        // Fall back to NIP-04 decryption for older messages (contains '?iv=')
        return await activeSigner.nip04Decrypt(event.content, otherPubkey);
      }
    } catch (e) {
      // If decryption fails, return raw content
      return event.content;
    }
  }

  /// Get raw encrypted content without decryption
  String get encryptedContent => event.content;

  /// Check if this message appears to be encrypted
  bool get isEncrypted =>
      encryptedContent.contains('?') || encryptedContent.startsWith('A');
}

/// Generated partial model mixin for DirectMessage
mixin PartialDirectMessageMixin on RegularPartialModel<DirectMessage> {
  /// The recipient's public key
  String? get receiver => event.getFirstTagValue('p');

  /// Sets the recipient's public key
  set receiver(String? value) => event.setTagValue('p', value);

  /// The message content (may be encrypted)
  String? get content => event.content.isEmpty ? null : event.content;

  /// Sets the message content
  set content(String? value) => event.content = value ?? '';

  /// Raw encrypted content (alias for content)
  String? get encryptedContent => event.content.isEmpty ? null : event.content;

  /// Sets the encrypted content
  set encryptedContent(String? value) => event.content = value ?? '';
}

/// Create and sign new direct message events.
///
/// Example usage:
/// ```dart
/// final dm = await PartialDirectMessage(content: 'Hello!', receiver: receiverPubkey).signWith(signer);
/// ```
class PartialDirectMessage extends RegularPartialModel<DirectMessage>
    with PartialDirectMessageMixin {
  PartialDirectMessage.fromMap(super.map) : super.fromMap();

  /// Create a new direct message with automatic encryption
  ///
  /// [content] - The plain text message content
  /// [receiver] - The recipient's public key or npub
  /// [useNip44] - Whether to use NIP-44 encryption (more secure, default)
  PartialDirectMessage({
    required String content,
    required String receiver,
    bool useNip44 = true, // Default to NIP-44 (more secure)
  }) {
    this.receiver = receiver.decodeShareable();

    // Set encrypted content - encryption will happen when signed
    _plainContent = content;
    _useNip44 = useNip44;

    // For now, set raw content - will be encrypted during signing
    this.content = content;
  }

  /// Create a direct message with pre-encrypted content
  ///
  /// [encryptedContent] - Already encrypted message content
  /// [receiver] - The recipient's public key or npub
  PartialDirectMessage.encrypted({
    required String encryptedContent,
    required String receiver,
  }) {
    content = encryptedContent;
    this.receiver = receiver.decodeShareable();
  }

  String? _plainContent;
  bool _useNip44 = true;

  /// Encrypt the content using the provided signer
  ///
  /// [signer] - The signer to use for encryption
  /// [recipientPubkey] - The recipient's public key
  Future<void> encryptContent(Signer signer, String recipientPubkey) async {
    if (_plainContent != null) {
      if (_useNip44) {
        content = await signer.nip44Encrypt(_plainContent!, recipientPubkey);
      } else {
        content = await signer.nip04Encrypt(_plainContent!, recipientPubkey);
      }
      _plainContent = null; // Clear plain content for security
    }
  }

  /// Get the plain content before encryption (if available)
  String? get plainContent => _plainContent;
}

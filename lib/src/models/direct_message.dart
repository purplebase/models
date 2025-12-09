part of models;

/// A direct message event (kind 4) for private communication between users.
///
/// **Encryption Strategy:**
/// - Content is plaintext BEFORE signing
/// - Content is encrypted DURING signing (in prepareForSigning)
/// - Content is always encrypted AFTER signing (locally and on relays)
/// - To read: must explicitly decrypt using signer
class DirectMessage extends RegularModel<DirectMessage>
    with EncryptableModel<DirectMessage> {
  DirectMessage.fromMap(super.map, super.ref) : super.fromMap();

  /// The recipient's npub (Bech32-encoded public key)
  String get receiver => Utils.encodeShareableFromString(
    event.getFirstTagValue('p')!,
    type: 'npub',
  );

  /// Get the message content (encrypted - must decrypt to read)
  String get message => content;

  @override
  String getEncryptionPubkey() {
    // For DMs, we encrypt to the recipient's pubkey
    final recipientPubkey = event.getFirstTagValue('p');
    if (recipientPubkey == null) {
      throw Exception('DirectMessage must have a receiver (p tag)');
    }
    return recipientPubkey;
  }

  @override
  bool get useNip04 => false; // Only NIP-44 is supported
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
/// **Encryption Strategy:**
/// - Content is plaintext before signing
/// - Content is encrypted during signing (in prepareForSigning)
/// - Content is always encrypted after signing
///
/// Example usage:
/// ```dart
/// final dm = PartialDirectMessage(content: 'Hello!', receiver: receiverPubkey);
/// await dm.signWith(signer); // Encrypts content during signing
/// await storage.save({dm}); // Saves encrypted content
/// ```
class PartialDirectMessage extends RegularPartialModel<DirectMessage>
    with PartialDirectMessageMixin, EncryptablePartialModel<DirectMessage> {
  PartialDirectMessage.fromMap(super.map) : super.fromMap();

  /// Create a new direct message
  ///
  /// [content] - The plain text message content
  /// [receiver] - The recipient's public key or npub
  PartialDirectMessage({
    required String content,
    required String receiver,
  }) {
    this.receiver = receiver.decodeShareable();
    setContent(content);
  }

  @override
  bool get useNip04 => false; // Only NIP-44 is supported

  @override
  String getEncryptionPubkey(Signer signer) {
    final recipientPubkey = event.getFirstTagValue('p');
    if (recipientPubkey == null) {
      throw Exception('DirectMessage must have a receiver (p tag)');
    }
    return recipientPubkey;
  }
}

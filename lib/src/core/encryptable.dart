part of models;

// ============================================================================
// Encryptable Models - Simple Encryption Strategy
// ============================================================================
//
// This file provides mixins for models that need encrypted content.
//
// ## Storage Strategy (SIMPLE)
//
// **Content lifecycle:**
// 1. **Before signing**: Content is plaintext in PartialModel
// 2. **During signing**: Content is encrypted in `prepareForSigning()` hook
// 3. **After signing**: Content is always encrypted (locally and on relays)
//
// **To read encrypted content:**
// - Explicitly decrypt using signer's decrypt methods
// - `await signer.nip44Decrypt(content, senderPubkey)`
// - `await signer.nip04Decrypt(content, senderPubkey)`
//
// ## Two Usage Patterns
//
// 1. **Self-encrypted lists (NIP-51)**: Private bookmarks, app lists, mute lists
//    - Encrypted to your own pubkey
//    - Example: `AppPack`, `BookmarkSet`, `MuteList`
//
// 2. **Peer-to-peer messages (NIP-04/44)**: Direct messages, NWC
//    - Encrypted to recipient's pubkey
//    - Example: `DirectMessage`, `NwcRequest`, `NwcResponse`
//
// ----------------------------------------------------------------------------
// Using Encryptable Models (Consumer API)
// ----------------------------------------------------------------------------
//
// ### Creating Encrypted Content
//
// ```dart
// // Example 1: Private App List (self-encrypted)
// final partial = PartialAppPack.withEncryptedApps(
//   name: 'Private Apps',
//   identifier: 'my-apps',
//   apps: ['32267:pubkey:vscode', '32267:pubkey:terminal'],
// );
// // Before signing: plaintext access works
// print(partial.privateAppIds); // ✅ Works
//
// final signed = await partial.signWith(signer);
// // After signing: content is encrypted
// print(signed.content); // "AQBxY3..." (encrypted)
//
// // To read: must decrypt
// final decrypted = await signer.nip44Decrypt(signed.content, signer.pubkey);
// final apps = jsonDecode(decrypted) as List;
//
// // Example 2: Private Bookmarks (self-encrypted)
// final bookmarks = PartialBookmarkSet.withEncryptedBookmarks(
//   name: 'Read Later',
//   identifier: 'reading',
//   bookmarks: [
//     ['e', eventId1],
//     ['a', '30023:pubkey:article'],
//   ],
// );
// final signed = await bookmarks.signWith(signer);
//
// // Example 3: Direct Message (peer-to-peer)
// final dm = PartialDirectMessage(
//   recipientPubkey: alicePubkey,
// )..setContent('Hello Alice!');
// final signed = await dm.signWith(signer);
// ```
//
// ### Reading Encrypted Content
//
// ```dart
// // After loading from storage, content is encrypted
// final appPack = await storage.query(Request<AppPack>(...)).first;
// print(appPack.content); // "AQBxY3..." (encrypted)
//
// // To read: explicitly decrypt
// final decrypted = await signer.nip44Decrypt(appPack.content, signer.pubkey);
// final apps = jsonDecode(decrypted) as List;
//
// // Direct messages: decrypt using sender's pubkey
// final dm = await storage.query(Request<DirectMessage>(...)).first;
// final plaintext = await signer.nip44Decrypt(dm.content, senderPubkey);
// ```
//
// ----------------------------------------------------------------------------
// Implementing Encrypted Models (Library Developer API)
// ----------------------------------------------------------------------------
//
// ### Pattern 1: Self-Encrypted Lists (NIP-51)
//
// For private lists that you manage and update frequently.
//
// ```dart
// class MyPrivateList extends ParameterizableReplaceableModel<MyPrivateList>
//     with EncryptableModel<MyPrivateList> {
//
//   // Required: Specify encryption pubkey (self = event.pubkey)
//   @override
//   String getEncryptionPubkey() => event.pubkey;
//
//   // To parse content, must decrypt first (content is always encrypted)
//   Future<List<String>> getPrivateItems(Signer signer) async {
//     if (content.isEmpty) return [];
//     final decrypted = await signer.nip44Decrypt(content, event.pubkey);
//     return (jsonDecode(decrypted) as List).cast<String>();
//   }
// }
//
// class PartialMyPrivateList
//     extends ParameterizableReplaceablePartialModel<MyPrivateList>
//     with EncryptablePartialModel<MyPrivateList> {
//
//   // Required: Specify encryption pubkey (self = signer.pubkey)
//   @override
//   String getEncryptionPubkey(Signer signer) => signer.pubkey;
//
//   // Set items (plaintext before signing)
//   void setPrivateItems(List<String> items) {
//     event.content = jsonEncode(items);
//   }
// }
// ```
//
// ### Pattern 2: Peer-to-Peer Messages (NIP-04/44)
//
// For direct messages and wallet commands.
//
// ```dart
// class SecretNote extends RegularModel<SecretNote>
//     with EncryptableModel<SecretNote> {
//
//   // Optional: Use NIP-04 for backward compatibility
//   @override
//   bool get useNip04 => true;
//
//   // Required: Specify encryption pubkey (recipient)
//   @override
//   String getEncryptionPubkey() {
//     // For peer-to-peer: recipient's pubkey from 'p' tag
//     return event.getFirstTagValue('p')!;
//   }
//
//   // Content is plaintext for messages you sent
//   String get message => content;
// }
//
// class PartialSecretNote extends PartialModel<SecretNote>
//     with EncryptablePartialModel<SecretNote> {
//
//   // Optional: Match NIP-04 usage
//   @override
//   bool get useNip04 => true;
//
//   // Required: Specify encryption pubkey (recipient)
//   @override
//   String getEncryptionPubkey(Signer signer) {
//     final recipientTag = event.getFirstTag('p');
//     if (recipientTag == null || recipientTag.length < 2) {
//       throw StateError('Recipient pubkey (p tag) is required');
//     }
//     return recipientTag[1];
//   }
//
//   PartialSecretNote({required String recipientPubkey, String? message}) {
//     event.tags = [['p', recipientPubkey]];
//     if (message != null) setContent(message);
//   }
// }
// ```
//
// ----------------------------------------------------------------------------
// Important Notes
// ----------------------------------------------------------------------------
//
// - **Encryption during signing**: Content is encrypted in `prepareForSigning()`
//   before the user sees the signing dialog. This ensures:
//   - User sees encrypted content (privacy!)
//   - Plaintext cached in metadata for instant access
//   - No double-encryption (checks if already encrypted)
//
// - **Metadata caching**: Plaintext cached in `event.metadata['_plaintext']`
//   - Persists across save/load cycles
//   - Enables synchronous `.content` access
//   - Stripped before publishing to relays
//
// - **Remote signer optimization**: No repeated decrypt prompts when reading
//   your own data. One sign = instant future access.
//
// - **NIP-04 vs NIP-44**: NIP-44 is the newer, more secure standard (default).
//   Only override `useNip04` to `true` for backward compatibility.
//
// - **Testing with dummySign()**: Tests can use `dummySign()` for synchronous
//   signing. Dummy encryption is deterministic for test assertions.
//
// - **Validation**: The `prepareForSigning()` hook validates that required
//   fields (like recipient pubkey) are present before encryption.
//
// ============================================================================

/// Mixin for models that support encrypted content in the `content` field.
///
/// **Storage Strategy:**
/// - Content is ALWAYS stored encrypted
/// - To read, use signer's decrypt methods explicitly
///
/// Models must override [getEncryptionPubkey] to specify encryption behavior.
mixin EncryptableModel<E extends Model<E>> on Model<E> {
  /// Get the pubkey used for encryption.
  ///
  /// - For self-encrypted content (NIP-51 lists): return `event.pubkey`
  /// - For peer-to-peer content (DMs): return the other party's pubkey
  String getEncryptionPubkey();

  /// Whether to use NIP-04 encryption (default: false, uses NIP-44).
  ///
  /// Override to return true for models that need NIP-04 compatibility.
  bool get useNip04 => false;

  /// Get the encrypted content.
  String get content => event.content;
}

/// Mixin for partial models that support encrypted content.
///
/// **Strategy:**
/// - Content stored as plaintext during construction
/// - Content encrypted in `prepareForSigning()` before signing
/// - After signing, content is always encrypted everywhere
/// - Simple: plaintext → sign → encrypted
///
/// Models must override [getEncryptionPubkey] to specify encryption behavior.
mixin EncryptablePartialModel<E extends Model<E>> on PartialModel<E> {
  /// Get the pubkey to use for encryption.
  ///
  /// - For self-encrypted content (NIP-51 lists): return `signer.pubkey`
  /// - For peer-to-peer content (DMs): return recipient's pubkey from tags
  String getEncryptionPubkey(Signer signer);

  /// Whether to use NIP-04 encryption (default: false, uses NIP-44).
  ///
  /// Override to return true for backward compatibility with NIP-04.
  bool get useNip04 => false;

  /// Set content (stored as plaintext until signing).
  ///
  /// [data] can be a String or any JSON-serializable object.
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
      event.content = useNip04
          ? await signer.nip04Encrypt(event.content, encPubkey)
          : await signer.nip44Encrypt(event.content, encPubkey);
    }

    await super.prepareForSigning(signer);
  }

  /// Check if content is already encrypted (to avoid double-encryption)
  bool _isAlreadyEncrypted(String content) {
    // NIP-04: contains '?iv=' delimiter
    if (content.contains('?iv=')) return true;

    // NIP-44: base64-encoded, typically long (>50 chars) and starts with 'A'
    // Check length to avoid false positives with short messages starting with 'A'
    if (content.length > 50 && content.startsWith('A')) {
      // Additional check: NIP-44 content is typically all base64 characters
      final base64Pattern = RegExp(r'^[A-Za-z0-9+/]+=*$');
      return base64Pattern.hasMatch(content);
    }

    return false;
  }
}

part of models;

/// A chat message event (kind 9) for community or group conversations.
///
/// Chat messages are public messages within communities or channels.
/// They can quote other messages and belong to specific communities.
/// Supports both NIP-CC communities (h tag contains pubkey) and NIP-29 groups (h tag contains group identifier).
class ChatMessage extends RegularModel<ChatMessage> {
  late final BelongsTo<ChatMessage> quotedMessage;
  late final BelongsTo<Community> community;

  ChatMessage.fromMap(super.map, super.ref) : super.fromMap() {
    // Quoted message relationship - handle invalid ID formats gracefully
    quotedMessage = BelongsTo(
      ref,
      Request<ChatMessage>.fromIds({?event.getFirstTagValue('q')}),
    );

    // Community relationship - NIP-CC backward compatible with NIP-29
    // h tag contains community pubkey, else NIP-29: null
    community = BelongsTo(
      ref,
      _isValidPubkey(groupId)
          ? RequestFilter<Community>(authors: {groupId!}).toRequest()
          : null,
    );
  }

  /// The message text content
  String get content => event.content;

  /// The group identifier or community pubkey from the h tag
  String? get groupId => event.getFirstTagValue('h');

  /// Whether this is a NIP-CC community (h tag is a pubkey)
  bool get isCommunikey => groupId != null && _isValidPubkey(groupId!);

  /// Helper to check if a string is a valid pubkey
  bool _isValidPubkey(String? value) {
    if (value == null) return false;
    return value.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);
  }
}

/// Generated partial model mixin for ChatMessage
mixin PartialChatMessageMixin on RegularPartialModel<ChatMessage> {
  /// The message text content
  String? get content => event.content.isEmpty ? null : event.content;

  /// Sets the message content
  set content(String? value) => event.content = value ?? '';

  /// The group identifier or community pubkey from the h tag
  String? get groupId => event.getFirstTagValue('h');

  /// Sets the group identifier or community pubkey
  set groupId(String? value) => event.setTagValue('h', value);
}

/// Create and sign new chat message events.
///
/// Example usage:
/// ```dart
/// final chatMessage = await PartialChatMessage('Hello community!').signWith(signer);
/// ```
class PartialChatMessage extends RegularPartialModel<ChatMessage>
    with PartialChatMessageMixin {
  PartialChatMessage.fromMap(super.map) : super.fromMap();

  /// Creates a new chat message
  ///
  /// [content] - The message text content
  /// [createdAt] - Optional creation timestamp
  /// [quotedMessage] - Optional message being quoted
  /// [community] - Optional community this message belongs to (NIP-CC)
  /// [groupId] - Optional group identifier for NIP-29 groups
  PartialChatMessage(
    String content, {
    DateTime? createdAt,
    ChatMessage? quotedMessage,
    Community? community, // NIP-CC
    String? groupId, // NIP-29
  }) {
    event.content = content;
    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    // Add quote reference if provided
    if (quotedMessage != null) {
      event.addTagValue('q', quotedMessage.id);
    }

    // Add community reference
    if (community != null) {
      // NIP-CC: use community pubkey
      event.addTagValue('h', community.event.pubkey);
    } else if (groupId != null) {
      // NIP-29: use group identifier
      event.addTagValue('h', groupId);
    }
  }
}

part of models;

/// A chat message event (kind 9) for community or group conversations.
///
/// Chat messages are public messages within communities or channels.
/// They can quote other messages and belong to specific communities.
class ChatMessage extends RegularModel<ChatMessage> {
  late final BelongsTo<ChatMessage> quotedMessage;
  late final BelongsTo<Community> community;

  ChatMessage.fromMap(super.map, super.ref) : super.fromMap() {
    quotedMessage = BelongsTo(
      ref,
      RequestFilter<ChatMessage>(
        tags: {
          '#q': {event.id},
        },
      ).toRequest(),
    );
    community = BelongsTo(
      ref,
      event.containsTag('h')
          ? Request<Community>.fromIds({event.getFirstTagValue('h')!})
          : null,
    );
  }

  /// The message text content
  String get content => event.content;
}

/// Generated partial model mixin for ChatMessage
mixin PartialChatMessageMixin on RegularPartialModel<ChatMessage> {
  /// The message text content
  String? get content => event.content.isEmpty ? null : event.content;

  /// Sets the message content
  set content(String? value) => event.content = value ?? '';
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
  /// [community] - Optional community this message belongs to
  PartialChatMessage(
    String content, {
    DateTime? createdAt,
    ChatMessage? quotedMessage,
    Community? community,
  }) {
    event.content = content;
    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    event.addTagValue('q', quotedMessage?.id);
    event.addTagValue('h', community?.id);
  }
}

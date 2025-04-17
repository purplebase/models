part of models;

class ChatMessage extends RegularEvent<ChatMessage> {
  late final BelongsTo<ChatMessage> quotedMessage;
  late final BelongsTo<Community> community;

  ChatMessage.fromMap(super.map, super.ref) : super.fromMap() {
    quotedMessage = BelongsTo(
      ref,
      RequestFilter(
        tags: {
          '#q': {internal.id}
        },
      ),
    );
    community = BelongsTo(
        ref,
        internal.containsTag('h')
            ? RequestFilter.fromReplaceableEvent(
                internal.getFirstTagValue('h')!)
            : null);
  }
  String get content => internal.content;
}

class PartialChatMessage extends RegularPartialEvent<ChatMessage> {
  PartialChatMessage(String content,
      {DateTime? createdAt, ChatMessage? quotedMessage, Community? community}) {
    internal.content = content;
    if (createdAt != null) {
      internal.createdAt = createdAt;
    }

    internal.addTagValue('q', quotedMessage?.id);
    internal.addTagValue('h', community?.id);
  }
}

part of models;

@GeneratePartialModel()
class ChatMessage extends RegularModel<ChatMessage> {
  late final BelongsTo<ChatMessage> quotedMessage;
  late final BelongsTo<Community> community;

  ChatMessage.fromMap(super.map, super.ref) : super.fromMap() {
    quotedMessage = BelongsTo(
      ref,
      RequestFilter<ChatMessage>(
        tags: {
          '#q': {event.id}
        },
      ).toRequest(),
    );
    community = BelongsTo(
        ref,
        event.containsTag('h')
            ? Request<Community>.fromIds({event.getFirstTagValue('h')!})
            : null);
  }
  String get content => event.content;
}

class PartialChatMessage extends RegularPartialModel<ChatMessage>
    with PartialChatMessageMixin {
  PartialChatMessage(String content,
      {DateTime? createdAt, ChatMessage? quotedMessage, Community? community}) {
    event.content = content;
    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    event.addTagValue('q', quotedMessage?.id);
    event.addTagValue('h', community?.id);
  }
}

part of models;

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
  String get content => event.content;
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for ChatMessage
mixin PartialChatMessageMixin on RegularPartialModel<ChatMessage> {
  String? get content => event.content.isEmpty ? null : event.content;
  set content(String? value) => event.content = value ?? '';
}

class PartialChatMessage extends RegularPartialModel<ChatMessage>
    with PartialChatMessageMixin {
  PartialChatMessage.fromMap(super.map) : super.fromMap();

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

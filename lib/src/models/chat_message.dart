import 'package:models/models.dart';

class ChatMessage extends RegularEvent<ChatMessage> {
  late final BelongsTo<ChatMessage> quotedMessage;
  late final BelongsTo<Community> community;

  ChatMessage.fromMap(super.map, super.ref) : super.fromMap() {
    quotedMessage = BelongsTo(
      ref,
      RequestFilter(
        kinds: {9},
        tags: {
          '#q': {internal.id}
        },
      ),
    );
    community = BelongsTo(ref,
        RequestFilter.fromReplaceableEvent(internal.getFirstTagValue('h')!));
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

    internal.addTagValue('q', quotedMessage?.internal.id);
    internal.addTagValue('h', community?.internal.id);
  }
}

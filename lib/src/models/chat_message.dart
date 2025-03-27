import 'package:models/models.dart';

class ChatMessage extends RegularEvent<ChatMessage> {
  late final BelongsTo<ChatMessage> quotedMessage;
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
  }
  String get content => internal.content;
}

class PartialChatMessage extends RegularPartialEvent<ChatMessage> {
  PartialChatMessage(String content,
      {DateTime? createdAt, ChatMessage? quotedMessage}) {
    internal.content = content;
    if (createdAt != null) {
      internal.createdAt = createdAt;
    }
    if (quotedMessage != null) {
      internal.addTagValue('q', quotedMessage.internal.id);
    }
  }
}

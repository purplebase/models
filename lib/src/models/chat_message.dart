import 'package:models/models.dart';

class ChatMessage extends RegularEvent<ChatMessage> {
  ChatMessage.fromMap(super.map, super.ref) : super.fromMap();
  String get message => internal.content;
}

class PartialChatMessage extends RegularPartialEvent<ChatMessage> {
  PartialChatMessage(String content,
      {DateTime? createdAt, ChatMessage? replyTo}) {
    internal.content = content;
    if (createdAt != null) {
      internal.createdAt = createdAt;
    }
    if (replyTo != null) {
      internal.addTagValue('q', replyTo.internal.id);
    }
  }
}

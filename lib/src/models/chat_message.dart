import 'package:models/models.dart';

// final String nevent;
// final String npub;
// final String message;
// final String profileName;
// final String profilePicUrl;
// final DateTime timestamp;
// final List<Reaction> reactions;
// final List<Zap> zaps;

class ChatMessage extends RegularEvent<ChatMessage> {
  ChatMessage.fromJson(super.map, super.ref) : super.fromJson();
}

class PartialChatMessage extends RegularPartialEvent<ChatMessage> {
  PartialChatMessage(String content,
      {DateTime? createdAt, ChatMessage? replyTo}) {
    event.content = content;
    if (createdAt != null) {
      event.createdAt = createdAt;
    }
    if (replyTo != null) {
      event.addTagValue('q', replyTo.event.id);
    }
  }
}

import 'package:models/models.dart';

class Reaction extends RegularEvent<Reaction> {
  Reaction.fromJson(super.map, super.ref) : super.fromJson();
  EmojiTag? get emojiTag {
    return event.getFirstTag('emoji') as EmojiTag?;
  }
}

class PartialReaction extends RegularPartialEvent<Reaction> {
  PartialReaction(
      {String? content, Profile? profile, Event? event, EmojiTag? emojiTag}) {
    if (emojiTag != null) {
      this.event.content = ':${emojiTag.name}:';
      this.event.addTag('emoji', emojiTag);
    } else {
      this.event.content = content ?? "+";
    }
    if (event != null) {
      linkEvent(event);
    }
    if (profile != null) {
      linkProfile(profile);
    }
  }
}

class EmojiTag extends TagValue {
  EmojiTag(String name, String url) : super([name, url]);
  String get name => value;
  String get url => values[1];
}

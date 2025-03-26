import 'package:models/models.dart';

class Reaction extends RegularEvent<Reaction> {
  late final BelongsTo<Event> event_;

  Reaction.fromJson(super.map, super.ref) : super.fromJson() {
    event_ = BelongsTo<Event>(
        ref, RequestFilter(ids: {internal.getFirstTagValue('e')!}));
  }

  (String name, String url)? get emojiTag {
    final tag = internal.getFirstTag('emoji');
    if (tag != null && tag.values.length > 1) {
      return (tag.value, tag.values[1]);
    }
    return null;
  }
}

class PartialReaction extends RegularPartialEvent<Reaction> {
  PartialReaction(
      {String? content,
      Profile? profile,
      Event? event,
      (String name, String url)? emojiTag}) {
    if (emojiTag != null) {
      final (name, url) = emojiTag;
      this.internal.content = ':$name:';
      this.internal.addTag('emoji', TagValue([name, url]));
    } else {
      this.internal.content = content ?? "+";
    }
    if (event != null) {
      linkEvent(event);
    }
    if (profile != null) {
      linkProfile(profile);
    }
  }
}

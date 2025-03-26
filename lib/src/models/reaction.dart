import 'package:models/models.dart';

class Reaction extends RegularEvent<Reaction> {
  late final BelongsTo<Event> reactedOn;
  late final BelongsTo<Profile> reactedOnAuthor;

  Reaction.fromMap(super.map, super.ref) : super.fromMap() {
    reactedOn = BelongsTo<Event>(
        ref, RequestFilter(ids: {internal.getFirstTagValue('e')!}));
    reactedOnAuthor = BelongsTo<Profile>(
        ref,
        RequestFilter(ids: {
          if (internal.containsTag('p')) internal.getFirstTagValue('p')!
        }));
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
      required Event reactedOn,
      Profile? reactedOnAuthor,
      (String name, String url)? emojiTag}) {
    if (emojiTag != null) {
      final (name, url) = emojiTag;
      internal.content = ':$name:';
      internal.addTag('emoji', TagValue([name, url]));
    } else {
      internal.content = content ?? "+";
    }
    linkEvent(reactedOn);
    if (reactedOnAuthor != null) {
      linkProfile(reactedOnAuthor);
    }
  }
}

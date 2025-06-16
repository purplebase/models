part of models;

@GeneratePartialModel()
class Reaction extends RegularModel<Reaction> with EmojiMixin {
  late final BelongsTo<Model> reactedOn;
  late final BelongsTo<Profile> reactedOnAuthor;

  Reaction.fromMap(super.map, super.ref) : super.fromMap() {
    reactedOn = BelongsTo(ref,
        RequestFilter<Model>(ids: {event.getFirstTagValue('e')!}).toRequest());
    reactedOnAuthor = BelongsTo(
        ref,
        RequestFilter<Profile>(
                ids: {if (event.containsTag('p')) event.getFirstTagValue('p')!})
            .toRequest());
  }
}

class PartialReaction extends RegularPartialModel<Reaction>
    with PartialReactionMixin, EmojiMixin {
  PartialReaction(
      {String? content,
      Model? reactedOn,
      Profile? reactedOnAuthor,
      (String, String)? emojiTag}) {
    if (emojiTag case (final name, final url)) {
      event.content = ':$name:';
      event.addTag('emoji', [name, url]);
    } else {
      event.content = content ?? "+";
    }
    if (reactedOn != null) {
      linkModel(reactedOn);
    }
    if (reactedOnAuthor != null) {
      linkProfile(reactedOnAuthor);
    }
  }
}

mixin EmojiMixin on ModelBase<Reaction> {
  (String name, String url)? get emojiTag {
    final tag = event.getFirstTag('emoji');
    if (tag != null && tag.length > 1) {
      return (tag[1], tag[2]);
    }
    return null;
  }
}

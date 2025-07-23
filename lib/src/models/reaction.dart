part of models;

class Reaction extends RegularModel<Reaction> with EmojiMixin {
  late final BelongsTo<Model> reactedOn;
  late final BelongsTo<Profile> reactedOnAuthor;

  Reaction.fromMap(super.map, super.ref) : super.fromMap() {
    reactedOn = BelongsTo(ref, Request.fromIds({?event.getFirstTagValue('e')}));
    reactedOnAuthor = BelongsTo(
      ref,
      Request.fromIds({?event.getFirstTagValue('p')}),
    );
  }
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for Reaction
mixin PartialReactionMixin on RegularPartialModel<Reaction> {
  // No event-based getters found in Reaction
}

class PartialReaction extends RegularPartialModel<Reaction>
    with PartialReactionMixin, EmojiMixin {
  PartialReaction.fromMap(Map<String, dynamic> map) : super.fromMap(map);
  PartialReaction({
    String? content,
    Model? reactedOn,
    Profile? reactedOnAuthor,
    (String, String)? emojiTag,
  }) {
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

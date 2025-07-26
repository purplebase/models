part of models;

/// A reaction event (kind 7) representing a user's response to another event.
///
/// Reactions are typically emoji responses (like, dislike, heart, etc.) to notes
/// or other content. The reaction content can be an emoji or text.
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

/// Generated partial model mixin for Reaction
mixin PartialReactionMixin on RegularPartialModel<Reaction> {
  // No event-based getters found in Reaction
}

/// Create and sign new reaction events.
///
/// Example usage:
/// ```dart
/// final reaction = await PartialReaction(content: '👍').signWith(signer);
/// ```
class PartialReaction extends RegularPartialModel<Reaction>
    with PartialReactionMixin, EmojiMixin {
  PartialReaction.fromMap(Map<String, dynamic> map) : super.fromMap(map);

  /// Creates a new reaction to content
  ///
  /// [content] - Emoji or text reaction content
  /// [reactedOn] - The content being reacted to
  /// [reactedOnAuthor] - Author of the content being reacted to
  /// [emojiTag] - Custom emoji (name, URL) if using custom emoji
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

/// Mixin for handling custom emoji in reactions
mixin EmojiMixin on ModelBase<Reaction> {
  /// Custom emoji tag (name, URL) if this reaction uses a custom emoji
  (String name, String url)? get emojiTag {
    final tag = event.getFirstTag('emoji');
    if (tag != null && tag.length > 1) {
      return (tag[1], tag[2]);
    }
    return null;
  }
}

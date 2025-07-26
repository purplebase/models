part of models;

/// A text note event (kind 1) in the Nostr protocol.
///
/// Notes are the most common type of content on Nostr, similar to tweets
/// or social media posts. They can be standalone posts or replies to other notes.
class Note extends RegularModel<Note> {
  /// The text content of this note.
  String get content => event.content;

  /// The root note in this conversation thread (if this is a reply).
  late final BelongsTo<Note> root;

  /// The note this is directly replying to (if this is a reply).
  late final BelongsTo<Note> replyTo;

  /// Whether this note is a root post (not a reply to anything).
  late final bool isRoot;

  /// All direct replies to this note.
  late final HasMany<Note> replies;

  /// All replies in the entire thread below this note.
  late final HasMany<Note> allReplies;

  /// All reposts of this note.
  late final HasMany<Repost> reposts;

  Note.fromMap(super.map, super.ref) : super.fromMap() {
    final tagsWithRoot = event
        .getTagSet('e')
        .where((t) => t.length > 3 && t[3] == 'root');
    isRoot = tagsWithRoot.isEmpty;

    root = BelongsTo(
      ref,
      isRoot
          ? null
          : RequestFilter<Note>(ids: {tagsWithRoot.first[1]}).toRequest(),
    );

    // Find the immediate replied-to note ID
    String? replyToId;
    if (!isRoot) {
      // First try to find a tag with 'reply' marker
      final tagsWithReply = event
          .getTagSet('e')
          .where((t) => t.length > 3 && t[3] == 'reply');
      if (tagsWithReply.isNotEmpty) {
        replyToId = tagsWithReply.first[1];
      } else {
        // If no 'reply' marker, check for single e tag (direct reply to root)
        final eTags = event.getTagSet('e');
        if (eTags.length == 1) {
          replyToId = eTags.first[1];
        } else if (eTags.length > 1) {
          // If multiple e tags but no 'reply' marker, use the last non-root tag
          final nonRootTags = eTags.where(
            (t) => t.length <= 3 || t[3] != 'root',
          );
          if (nonRootTags.isNotEmpty) {
            replyToId = nonRootTags.last[1];
          }
        }
      }
    }

    replyTo = BelongsTo(
      ref,
      replyToId != null
          ? RequestFilter<Note>(ids: {replyToId}).toRequest()
          : null,
    );

    allReplies = HasMany(
      ref,
      RequestFilter<Note>(
        tags: {
          '#e': {event.id},
        },
        where: (e) {
          // Querying in-memory as nostr filters do not support this
          // Passes if its matching e tag with ID has a root marker
          final tags = e.event.getTagSet('e');
          return tags.any(
            (e) => e.length > 3 && e[1] == event.id && e[3] == 'root',
          );
        },
      ).toRequest(),
    );
    replies = HasMany(
      ref,
      RequestFilter<Note>(
        tags: {
          '#e': {event.id},
        },
        where: (e) {
          // Querying in-memory as nostr filters do not support this
          // Only returns events with a single e tag with a root marker
          final tags = e.event.getTagSet('e');
          return tags.length == 1 &&
              tags.first.length > 3 &&
              tags.first[3] == 'root';
        },
      ).toRequest(),
    );

    reposts = HasMany(
      ref,
      RequestFilter<Repost>(
        tags: {
          '#e': {event.id},
        },
      ).toRequest(),
    );
  }
}

/// Generated partial model mixin for Note
mixin PartialNoteMixin on RegularPartialModel<Note> {
  /// The text content of the note
  String? get content => event.content.isEmpty ? null : event.content;

  /// Sets the text content of the note
  set content(String? value) => event.content = value ?? '';
}

class PartialNote extends RegularPartialModel<Note> with PartialNoteMixin {
  PartialNote.fromMap(super.map) : super.fromMap();

  /// Creates a new note with the specified content
  ///
  /// [content] - The text content of the note
  /// [createdAt] - Optional creation timestamp
  /// [replyTo] - Optional note this is replying to
  /// [root] - Optional root note in the conversation thread
  /// [tags] - Optional hashtags for the note
  PartialNote(
    String content, {
    DateTime? createdAt,
    Note? replyTo,
    Note? root,
    Set<String> tags = const {},
  }) {
    event.content = content;
    if (createdAt != null) {
      event.createdAt = createdAt;
    }
    if (replyTo != null) {
      if (replyTo.isRoot) {
        // replyTo is the root (has no markers to root)
        linkModel(replyTo, marker: 'root');
      } else if (root != null) {
        linkModel(root, marker: 'root');
        linkModel(replyTo, marker: 'reply');
      }
    }
    for (final tag in tags) {
      event.addTagValue('t', tag);
    }
  }
}

import 'package:collection/collection.dart';
import 'package:models/models.dart';

class Note extends RegularEvent<Note> {
  String get content => internal.content;

  late final BelongsTo<Note> root;
  late final bool isRoot;
  late final HasMany<Note> replies;
  late final HasMany<Note> allReplies;

  Note.fromMap(super.map, super.ref) : super.fromMap() {
    final tagsWithRoot = internal
        .getTagSet('e')
        .where((t) => t is EventTagValue && t.marker == EventMarker.root);
    isRoot = tagsWithRoot.isEmpty;

    root = BelongsTo(
        ref,
        isRoot
            ? null
            : RequestFilter(kinds: {1}, ids: {tagsWithRoot.first.value}));

    allReplies = HasMany(
      ref,
      RequestFilter(
        kinds: {1},
        tags: {
          '#e': {internal.id}
        },
        where: (e) {
          // Querying in-memory as nostr filters do not support this
          // Passes if its matching e tag with ID has a root marker
          final tags = e.internal.getTagSet('e');
          return tags.any((e) =>
              e is EventTagValue &&
              e.marker == EventMarker.root &&
              e.value == internal.id);
        },
      ),
    );
    replies = HasMany(
      ref,
      RequestFilter(
        kinds: {1},
        tags: {
          '#e': {internal.id}
        },
        where: (e) {
          // Querying in-memory as nostr filters do not support this
          // Only returns events with a single e tag with a root marker
          final tags = e.internal.getTagSet('e');
          return tags.length == 1 &&
              tags.first is EventTagValue &&
              (tags.first as EventTagValue).marker == EventMarker.root;
        },
      ),
    );
  }
}

class PartialNote extends RegularPartialEvent<Note> {
  PartialNote(String content,
      {DateTime? createdAt, Note? replyTo, Set<String> tags = const {}}) {
    internal.content = content;
    if (createdAt != null) {
      internal.createdAt = createdAt;
    }
    if (replyTo != null) {
      if (replyTo.isRoot) {
        // replyTo is the root (has no markers to root)
        linkEvent(replyTo, marker: EventMarker.root);
      } else {
        linkEvent(replyTo.root.value!, marker: EventMarker.root);
        linkEvent(replyTo, marker: EventMarker.reply);
      }
    }
    for (final tag in tags) {
      internal.addTagValue('t', tag);
    }
  }
}

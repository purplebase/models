part of models;

@GeneratePartialModel()
class Note extends RegularModel<Note> {
  String get content => event.content;

  late final BelongsTo<Note> root;
  late final bool isRoot;
  late final HasMany<Note> replies;
  late final HasMany<Note> allReplies;
  late final HasMany<Repost> reposts;

  Note.fromMap(super.map, super.ref) : super.fromMap() {
    final tagsWithRoot =
        event.getTagSet('e').where((t) => t.length > 3 && t[3] == 'root');
    isRoot = tagsWithRoot.isEmpty;

    root = BelongsTo(
        ref,
        isRoot
            ? null
            : RequestFilter<Note>(ids: {tagsWithRoot.first[1]}).toRequest());

    allReplies = HasMany(
      ref,
      RequestFilter<Note>(
        tags: {
          '#e': {event.id}
        },
        where: (e) {
          // Querying in-memory as nostr filters do not support this
          // Passes if its matching e tag with ID has a root marker
          final tags = e.event.getTagSet('e');
          return tags
              .any((e) => e.length > 3 && e[1] == event.id && e[3] == 'root');
        },
      ).toRequest(),
    );
    replies = HasMany(
      ref,
      RequestFilter<Note>(
        tags: {
          '#e': {event.id}
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
          '#e': {event.id}
        },
      ).toRequest(),
    );
  }
}

class PartialNote extends RegularPartialModel<Note> with PartialNoteMixin {
  PartialNote.fromMap(super.map) : super.fromMap();

  PartialNote(String content,
      {DateTime? createdAt,
      Note? replyTo,
      Note? root,
      Set<String> tags = const {}}) {
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

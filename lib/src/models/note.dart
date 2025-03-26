import 'package:models/models.dart';

class Note extends RegularEvent<Note> {
  String get content => internal.content;

  late final HasMany<Note> notes;
  late final HasMany<Note> allNotes;

  Note.fromMap(super.map, super.ref) : super.fromMap() {
    allNotes = HasMany(
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
    notes = HasMany(
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
      {DateTime? createdAt, Set<String> tags = const {}}) {
    internal.content = content;
    if (createdAt != null) {
      internal.createdAt = createdAt;
    }
    for (final tag in tags) {
      internal.addTagValue('t', tag);
    }
  }
}

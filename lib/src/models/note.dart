import 'package:models/models.dart';

class Note extends RegularEvent<Note> {
  String get content => event.content;
  late final BelongsTo<Profile> profile;

  Note.fromJson(super.map, super.ref) : super.fromJson() {
    profile =
        BelongsTo(ref, RequestFilter(kinds: {0}, authors: {event.pubkey}));
  }
}

class PartialNote extends RegularPartialEvent<Note> {
  PartialNote(String content,
      {DateTime? createdAt, Set<String> tags = const {}}) {
    event.content = content;
    if (createdAt != null) {
      event.createdAt = createdAt;
    }
    for (final tag in tags) {
      event.addTag('#t', tag);
    }
  }
}

import 'package:models/models.dart';

class Note extends RegularEvent<Note> {
  String get content => internal.content;
  late final BelongsTo<Profile> profile;
  late final HasMany<Note> notes;
  late final HasMany<Reaction> reactions;

  Note.fromJson(super.map, super.ref) : super.fromJson() {
    profile =
        BelongsTo(ref, RequestFilter(kinds: {0}, authors: {internal.pubkey}));
    notes = HasMany(
      ref,
      RequestFilter(kinds: {
        1
      }, tags: {
        '#e': {internal.id}
      }, tagMarker: EventMarker.reply),
    );
    reactions = HasMany(
      ref,
      RequestFilter(kinds: {
        7
      }, tags: {
        '#e': {internal.id}
      }),
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

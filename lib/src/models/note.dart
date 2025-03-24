import 'package:models/src/event.dart';
import 'package:models/src/models/profile.dart';
import 'package:models/src/models/relationship.dart';
import 'package:models/src/storage/notifiers.dart';
import 'package:riverpod/riverpod.dart';

class Note extends RegularEvent<Note> {
  String get content => event.content;
  late final BelongsTo<Profile> profile;

  Note.fromJson(super.map, super.ref) : super.fromJson() {
    profile = ProfileBelongsTo(ref, event.pubkey);
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

class NoteHasMany extends HasMany<Note> {
  final Ref ref;
  final String pubkey;
  NoteHasMany(this.ref, this.pubkey);

  @override
  List<Note> toList() {
    final s = ref.read(query(kinds: {1}, authors: {pubkey}, storageOnly: true));
    return s.models.whereType<Note>().toList();
  }
}

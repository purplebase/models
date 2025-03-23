import 'package:models/src/event.dart';

class Note extends RegularEvent<Note> {
  Note.fromJson(super.map) : super.fromJson();
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

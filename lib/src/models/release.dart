import 'package:models/src/core/event.dart';

class Release extends ParameterizableReplaceableEvent<Release> {
  Release.fromMap(super.map, super.ref) : super.fromMap();

  String get releaseNotes => internal.content;
  String get version => internal.identifier.split('@').last;
}

class PartialRelease extends ParameterizableReplaceablePartialEvent<Release> {
  set releaseNotes(String value) => internal.content = value;
}

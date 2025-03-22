import 'package:models/src/event.dart';

class Release = ParameterizableReplaceableEvent<Release> with ReleaseMixin;

class PartialRelease = ParameterizableReplaceablePartialEvent<Release>
    with ReleaseMixin, PartialReleaseMixin;

mixin ReleaseMixin on EventBase<Release>, IdentifierMixin {
  String get releaseNotes => event.content;
  String get version => identifier!.split('@').last;
}

mixin PartialReleaseMixin on PartialEventBase<Release>, IdentifierMixin {
  set releaseNotes(String value) => event.content = value;
}

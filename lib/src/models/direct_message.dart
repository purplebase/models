import 'package:models/src/core/event.dart';
import 'package:models/src/models/profile.dart';

mixin _DirectMessageMixin on EventBase<DirectMessage> {
  String get receiver => event.getFirstTagValue('p')!.npub;
  String get content => event.content;
}

class DirectMessage = RegularEvent<DirectMessage> with _DirectMessageMixin;

class PartialDirectMessage extends RegularPartialEvent<DirectMessage>
    with _DirectMessageMixin {
  PartialDirectMessage({
    required String content,
    required String receiver,
  }) {
    event.content = content;
    event.setTagValue('p', receiver.hexKey);
  }
}

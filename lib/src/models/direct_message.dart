import 'package:models/src/core/event.dart';
import 'package:models/src/models/profile.dart';

mixin _DirectMessageMixin on EventBase<DirectMessage> {
  String get receiver => internal.getFirstTagValue('p')!.npub;
  String get content => internal.content;
}

class DirectMessage = RegularEvent<DirectMessage> with _DirectMessageMixin;

class PartialDirectMessage extends RegularPartialEvent<DirectMessage>
    with _DirectMessageMixin {
  PartialDirectMessage({
    required String content,
    required String receiver,
  }) {
    internal.content = content;
    internal.setTagValue('p', receiver.hexKey);
  }
}

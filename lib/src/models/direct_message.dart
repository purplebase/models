part of models;

class DirectMessage extends RegularEvent<DirectMessage> {
  DirectMessage.fromMap(super.map, super.ref) : super.fromMap();

  String get receiver => Profile.npubFromHex(internal.getFirstTagValue('p')!);
  String get content => internal.content;
}

class PartialDirectMessage extends RegularPartialEvent<DirectMessage> {
  PartialDirectMessage({
    required String content,
    required String receiver,
  }) {
    internal.content = content;
    internal.setTagValue('p', Profile.hexFromNpub(receiver));
  }
}

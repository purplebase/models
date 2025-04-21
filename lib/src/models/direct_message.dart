part of models;

class DirectMessage extends RegularModel<DirectMessage> {
  DirectMessage.fromMap(super.map, super.ref) : super.fromMap();

  String get receiver => Utils.npubFromHex(event.getFirstTagValue('p')!);
  String get content => event.content;
}

class PartialDirectMessage extends RegularPartialModel<DirectMessage> {
  PartialDirectMessage({
    required String content,
    required String receiver,
  }) {
    event.content = content;
    event.setTagValue('p', Utils.hexFromNpub(receiver));
  }
}

part of models;

@GeneratePartialModel()
class DirectMessage extends RegularModel<DirectMessage> {
  DirectMessage.fromMap(super.map, super.ref) : super.fromMap();

  String get receiver => Utils.npubFromHex(event.getFirstTagValue('p')!);
  String get content => event.content;
}

class PartialDirectMessage extends RegularPartialModel<DirectMessage>
    with PartialDirectMessageMixin {
  PartialDirectMessage({
    required String content,
    required String receiver,
  }) {
    this.content = content;
    this.receiver = Utils.hexFromNpub(receiver);
  }
}

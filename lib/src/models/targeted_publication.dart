part of models;

@GeneratePartialModel()
class TargetedPublication
    extends ParameterizableReplaceableModel<TargetedPublication> {
  late final BelongsTo<Model> model;
  late final HasMany<Community> communities;

  TargetedPublication.fromMap(super.map, super.ref) : super.fromMap() {
    if (event.getFirstTagValue('e') != null) {
      model = BelongsTo(
          ref,
          RequestFilter<Model>(ids: {event.getFirstTagValue('e')!})
              .toRequest());
    } else {
      model = BelongsTo(
          ref, Request<Model>.fromIds({event.getFirstTagValue('a')!}));
    }

    // This is only possible because communities are replaceable events (without a d tag)
    final req = RequestFilter<Community>(authors: communityPubkeys).toRequest();
    communities = HasMany(ref, req);
  }

  int get targetedKind => int.parse(event.getFirstTagValue('k')!);
  Set<String> get relayUrls => event.getTagSetValues('r');
  Set<String> get communityPubkeys => event.getTagSetValues('p');
}

class PartialTargetedPublication
    extends ParameterizableReplaceablePartialModel<TargetedPublication>
    with PartialTargetedPublicationMixin {
  PartialTargetedPublication.fromMap(super.map) : super.fromMap();

  PartialTargetedPublication(Model model,
      {required Set<Community> communities, Set<String>? relayUrls}) {
    linkModel(model);

    event.addTagValue('d', Utils.generateRandomHex64());
    targetedKind = model.event.kind;

    communityPubkeys = communities.map((c) => c.event.pubkey).toSet();
    if (relayUrls != null) {
      this.relayUrls = relayUrls;
    }
  }
}

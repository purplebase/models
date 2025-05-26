part of models;

@GeneratePartialModel()
class TargetedPublication
    extends ParameterizableReplaceableModel<TargetedPublication> {
  late final BelongsTo<Model> model;
  late final HasMany<Community> communities;

  TargetedPublication.fromMap(super.map, super.ref) : super.fromMap() {
    if (event.getFirstTagValue('e') != null) {
      model =
          BelongsTo(ref, RequestFilter(ids: {event.getFirstTagValue('e')!}));
    } else {
      final addressableId = event.getFirstTagValue('a')!;
      model = BelongsTo(ref, RequestFilter.fromReplaceable(addressableId));
    }

    // This is only possible because communities are replaceable events
    // without a parameter, PREs would be impossible to combine into one req
    final communityReqs = event
        .getTagSetValues('p')
        .nonNulls
        .map(RequestFilter<Community>.fromReplaceable);
    final req =
        mergeMultipleRequests<Community>(communityReqs.toList()).firstOrNull;
    communities = HasMany(ref, req);
  }

  int get targetedKind => int.parse(event.getFirstTagValue('k')!);
  Set<String> get relayUrls => event.getTagSetValues('r');
  Set<String> get communityPubkeys => event.getTagSetValues('p');
}

class PartialTargetedPublication
    extends ParameterizableReplaceablePartialEvent<TargetedPublication>
    with PartialTargetedPublicationMixin {
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

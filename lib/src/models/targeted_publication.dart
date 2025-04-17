part of models;

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
}

class PartialTargetedPublication
    extends ParameterizableReplaceablePartialEvent<TargetedPublication> {
  PartialTargetedPublication(Model model,
      {required Set<Community> communities, Set<String>? relayUrls}) {
    event.addTagValue('d', generate64Hex());
    event.addTagValue(model.event.addressableIdTagLetter, model.id);
    event.addTagValue('k', model.event.kind.toString());
    for (final community in communities) {
      event.addTagValue('p', community.id);
    }
    if (relayUrls != null) {
      for (final relayUrl in relayUrls) {
        event.addTagValue('r', relayUrl);
      }
    }
  }

  void addCommunityPubkey(String value) => event.addTagValue('p', value);
  set eventId(String value) => event.addTagValue('e', value);
  set eventKind(int value) => event.addTagValue('k', value.toString());
}

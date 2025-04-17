part of models;

class TargetedPublication
    extends ParameterizableReplaceableEvent<TargetedPublication> {
  late final BelongsTo<Event> event;
  late final HasMany<Community> communities;

  TargetedPublication.fromMap(super.map, super.ref) : super.fromMap() {
    if (internal.getFirstTagValue('e') != null) {
      event =
          BelongsTo(ref, RequestFilter(ids: {internal.getFirstTagValue('e')!}));
    } else {
      final addressableId = internal.getFirstTagValue('a')!;
      event = BelongsTo(ref, RequestFilter.fromReplaceableEvent(addressableId));
    }

    // This is only possible because communities are replaceable events
    // without a parameter, PREs would be impossible to combine into one req
    final communityReqs = internal
        .getTagSetValues('p')
        .nonNulls
        .map(RequestFilter.fromReplaceableEvent);
    final req = mergeMultipleRequests(communityReqs.toList()).firstOrNull;
    communities = HasMany(ref, req);
  }

  int get targetedKind => int.parse(internal.getFirstTagValue('k')!);
  Set<String> get relayUrls => internal.getTagSetValues('r');
}

class PartialTargetedPublication
    extends ParameterizableReplaceablePartialEvent<TargetedPublication> {
  PartialTargetedPublication(Event event,
      {required Set<Community> communities, Set<String>? relayUrls}) {
    internal.addTagValue('d', generate64Hex());
    internal.addTagValue(event.internal.addressableIdTagLetter, event.id);
    internal.addTagValue('k', event.internal.kind.toString());
    for (final community in communities) {
      internal.addTagValue('p', community.id);
    }
    if (relayUrls != null) {
      for (final relayUrl in relayUrls) {
        internal.addTagValue('r', relayUrl);
      }
    }
  }

  void addCommunityPubkey(String value) => internal.addTagValue('p', value);
  set eventId(String value) => internal.addTagValue('e', value);
  set eventKind(int value) => internal.addTagValue('k', value.toString());
}

part of models;

class TargetedPublication
    extends ParameterizableReplaceableModel<TargetedPublication> {
  late final BelongsTo<Model> model;
  late final HasMany<Community> communities;

  TargetedPublication.fromMap(super.map, super.ref) : super.fromMap() {
    model = BelongsTo(
      ref,
      Request.fromIds({
        ?event.getFirstTagValue('e'),
        ?event.getFirstTagValue('a'),
      }),
    );

    // This is only possible because communities are replaceable events (without a d tag)
    final req = RequestFilter<Community>(authors: communityPubkeys).toRequest();
    communities = HasMany(ref, req);
  }

  int get targetedKind => int.parse(event.getFirstTagValue('k')!);
  Set<String> get relayUrls => event.getTagSetValues('r');
  Set<String> get communityPubkeys => event.getTagSetValues('p');
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for TargetedPublication
mixin PartialTargetedPublicationMixin
    on ParameterizableReplaceablePartialModel<TargetedPublication> {
  int? get targetedKind => int.tryParse(event.getFirstTagValue('k') ?? '');
  set targetedKind(int? value) => event.setTagValue('k', value?.toString());
  Set<String> get relayUrls => event.getTagSetValues('r');
  set relayUrls(Set<String> value) => event.setTagValues('r', value);
  void addRelayUrl(String? value) => event.addTagValue('r', value);
  void removeRelayUrl(String? value) => event.removeTagWithValue('r', value);
  Set<String> get communityPubkeys => event.getTagSetValues('p');
  set communityPubkeys(Set<String> value) => event.setTagValues('p', value);
  void addCommunityPubkey(String? value) => event.addTagValue('p', value);
  void removeCommunityPubkey(String? value) =>
      event.removeTagWithValue('p', value);
}

class PartialTargetedPublication
    extends ParameterizableReplaceablePartialModel<TargetedPublication>
    with PartialTargetedPublicationMixin {
  PartialTargetedPublication.fromMap(super.map) : super.fromMap();

  PartialTargetedPublication(
    Model model, {
    required Set<Community> communities,
    Set<String>? relayUrls,
  }) {
    linkModel(model);

    event.addTagValue('d', Utils.generateRandomHex64());
    targetedKind = model.event.kind;

    communityPubkeys = communities.map((c) => c.event.pubkey).toSet();
    if (relayUrls != null) {
      this.relayUrls = relayUrls;
    }
  }
}

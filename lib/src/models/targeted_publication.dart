part of models;

/// A targeted publication event (kind 30222) for publishing content to specific communities.
///
/// Targeted publications allow publishing content to particular communities
/// or relay groups, providing controlled distribution and moderation.
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

  /// The kind number of the content being targeted for publication
  int get targetedKind => int.parse(event.getFirstTagValue('k')!);

  /// Set of relay URLs where this content should be distributed
  Set<String> get relayUrls => event.getTagSetValues('r');

  /// Set of community public keys that are being targeted for this publication
  Set<String> get communityPubkeys => event.getTagSetValues('p');
}

/// Generated partial model mixin for TargetedPublication
mixin PartialTargetedPublicationMixin
    on ParameterizableReplaceablePartialModel<TargetedPublication> {
  /// The kind number of the content being targeted for publication
  int? get targetedKind => int.tryParse(event.getFirstTagValue('k') ?? '');

  /// Sets the kind number of the content being targeted
  set targetedKind(int? value) => event.setTagValue('k', value?.toString());

  /// Set of relay URLs where this content should be distributed
  Set<String> get relayUrls => event.getTagSetValues('r');

  /// Sets the relay URLs for content distribution
  set relayUrls(Set<String> value) => event.setTagValues('r', value);

  /// Adds a relay URL to the distribution list
  void addRelayUrl(String? value) => event.addTagValue('r', value);

  /// Removes a relay URL from the distribution list
  void removeRelayUrl(String? value) => event.removeTagWithValue('r', value);

  /// Set of community public keys that are being targeted
  Set<String> get communityPubkeys => event.getTagSetValues('p');

  /// Sets the community public keys being targeted
  set communityPubkeys(Set<String> value) => event.setTagValues('p', value);

  /// Adds a community public key to the target list
  void addCommunityPubkey(String? value) => event.addTagValue('p', value);

  /// Removes a community public key from the target list
  void removeCommunityPubkey(String? value) =>
      event.removeTagWithValue('p', value);
}

class PartialTargetedPublication
    extends ParameterizableReplaceablePartialModel<TargetedPublication>
    with PartialTargetedPublicationMixin {
  PartialTargetedPublication.fromMap(super.map) : super.fromMap();

  /// Creates a new targeted publication for distributing content to specific communities
  ///
  /// [model] - The content model to be published
  /// [communities] - The communities to target for publication
  /// [relayUrls] - Optional relay URLs for distribution
  /// [identifier] - Optional identifier for the targeted publication
  PartialTargetedPublication(
    Model model, {
    required Set<Community> communities,
    Set<String>? relayUrls,
    String? identifier,
  }) {
    linkModel(model);

    // Use provided identifier or generate one
    event.addTagValue('d', identifier ?? Utils.generateRandomHex64());
    targetedKind = model.event.kind;

    communityPubkeys = communities.map((c) => c.event.pubkey).toSet();
    if (relayUrls != null) {
      this.relayUrls = relayUrls;
    }
  }

  /// Creates a targeted publication for an existing event
  ///
  /// [eventId] - ID of the existing event to target
  /// [eventKind] - Kind of the existing event
  /// [communities] - The communities to target for publication
  /// [relayUrls] - Optional relay URLs for distribution
  /// [identifier] - Optional identifier for the targeted publication
  PartialTargetedPublication.forExistingEvent(
    String eventId,
    int eventKind, {
    required Set<Community> communities,
    Set<String>? relayUrls,
    String? identifier,
  }) {
    event.addTagValue('e', eventId);
    event.addTagValue('k', eventKind.toString());
    event.addTagValue('d', identifier ?? Utils.generateRandomHex64());

    communityPubkeys = communities.map((c) => c.event.pubkey).toSet();
    if (relayUrls != null) {
      this.relayUrls = relayUrls;
    }
  }
}

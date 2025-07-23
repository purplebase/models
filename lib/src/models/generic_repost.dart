part of models;

@GeneratePartialModel()
class GenericRepost extends RegularModel<GenericRepost> {
  String get content => event.content;

  /// The kind of the reposted event
  int? get repostedEventKind {
    final kTag = event.getFirstTagValue('k');
    return kTag != null ? int.tryParse(kTag) : null;
  }

  /// The relay URL where the reposted event can be fetched
  String? get relayUrl {
    final eTags = event.getTagSet('e');
    for (final tag in eTags) {
      if (tag.length > 2 && tag[2].isNotEmpty) {
        return tag[2];
      }
    }
    return null;
  }

  /// The ID of the reposted event
  String? get repostedEventId => event.getFirstTagValue('e');

  /// The pubkey of the author of the reposted event
  String? get repostedEventPubkey => event.getFirstTagValue('p');

  /// The event that is being reposted
  late final BelongsTo<Model> repostedEvent;

  /// The author of the reposted event
  late final BelongsTo<Profile> repostedEventAuthor;

  GenericRepost.fromMap(super.map, super.ref) : super.fromMap() {
    // According to NIP-18, generic repost event MUST include an 'e' tag with the id of the event being reposted
    final eTag = event.getFirstTagValue('e');
    repostedEvent = BelongsTo(ref, Request.fromIds({?eTag}));

    // Should include a 'p' tag with the pubkey of the event being reposted
    final pTag = event.getFirstTagValue('p');
    repostedEventAuthor = BelongsTo(
      ref,
      RequestFilter<Profile>(ids: {if (pTag != null) pTag}).toRequest(),
    );
  }
}

class PartialGenericRepost extends RegularPartialModel<GenericRepost>
    with PartialGenericRepostMixin {
  PartialGenericRepost.fromMap(super.map) : super.fromMap();

  PartialGenericRepost({
    String? content,
    Model? repostedEvent,
    Profile? repostedEventAuthor,
    String? relayUrl,
    int? repostedEventKind,
  }) {
    this.content = content;
    this.repostedEventKind = repostedEventKind;

    if (repostedEvent != null) {
      // Add the required 'e' tag with the event ID and optional relay URL
      linkModel(repostedEvent, relayUrl: relayUrl);
      // Set the 'p' tag with the event author's pubkey
      repostedEventPubkey = repostedEvent.event.pubkey;
    }

    if (repostedEventAuthor != null) {
      repostedEventPubkey = repostedEventAuthor.pubkey;
    }
  }
}

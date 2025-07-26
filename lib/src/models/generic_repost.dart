part of models;

/// A generic repost event (kind 16) for sharing any type of event.
///
/// Generic reposts allow sharing of any event type, not just notes.
/// They preserve the original event information while allowing commentary.
class GenericRepost extends RegularModel<GenericRepost> {
  /// Optional commentary on the repost
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

/// Generated partial model mixin for GenericRepost
mixin PartialGenericRepostMixin on RegularPartialModel<GenericRepost> {
  /// Optional commentary on the repost
  String? get content => event.content.isEmpty ? null : event.content;

  /// Sets the repost commentary
  set content(String? value) => event.content = value ?? '';

  /// Kind number of the reposted event
  int? get repostedEventKind => int.tryParse(event.getFirstTagValue('k') ?? '');

  /// Sets the reposted event kind
  set repostedEventKind(int? value) =>
      event.setTagValue('k', value?.toString());

  /// ID of the reposted event
  String? get repostedEventId => event.getFirstTagValue('e');

  /// Sets the reposted event ID
  set repostedEventId(String? value) => event.setTagValue('e', value);

  /// Public key of the reposted event's author
  String? get repostedEventPubkey => event.getFirstTagValue('p');

  /// Sets the reposted event author's pubkey
  set repostedEventPubkey(String? value) => event.setTagValue('p', value);
}

/// Create and sign new generic repost events.
///
/// Example usage:
/// ```dart
/// final genericRepost = await PartialGenericRepost(repostedEvent: event, repostedEventKind: 1).signWith(signer);
/// ```
class PartialGenericRepost extends RegularPartialModel<GenericRepost>
    with PartialGenericRepostMixin {
  PartialGenericRepost.fromMap(super.map) : super.fromMap();

  /// Creates a new generic repost
  ///
  /// [content] - Optional commentary on the repost
  /// [repostedEvent] - The event being reposted
  /// [repostedEventAuthor] - The author of the original event
  /// [relayUrl] - Optional relay URL where the original can be found
  /// [repostedEventKind] - Kind number of the original event
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

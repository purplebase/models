part of models;

/// A repost event (kind 6) for sharing existing notes.
///
/// Reposts amplify existing content by referencing the original note
/// and optionally adding commentary. They help spread content across
/// the network while preserving attribution.
class Repost extends RegularModel<Repost> {
  /// Optional commentary on the repost
  String get content => event.content;

  /// The relay URL where the reposted note can be fetched
  String? get relayUrl {
    final eTags = event.getTagSet('e');
    for (final tag in eTags) {
      if (tag.length > 2 && tag[2].isNotEmpty) {
        return tag[2];
      }
    }
    return null;
  }

  /// The ID of the reposted note
  String? get repostedNoteId => event.getFirstTagValue('e');

  /// The pubkey of the author of the reposted note
  String? get repostedNotePubkey => event.getFirstTagValue('p');

  /// The note that is being reposted
  late final BelongsTo<Note> repostedNote;

  /// The author of the reposted note
  late final BelongsTo<Profile> repostedNoteAuthor;

  Repost.fromMap(super.map, super.ref) : super.fromMap() {
    // According to NIP-18, repost event MUST include an 'e' tag with the id of the note being reposted
    final eTag = event.getFirstTagValue('e');
    if (eTag == null) {
      throw Exception(
        'Repost event must contain an "e" tag with the reposted note ID',
      );
    }

    repostedNote = BelongsTo(ref, RequestFilter<Note>(ids: {eTag}).toRequest());

    // Should include a 'p' tag with the pubkey of the event being reposted
    final pTag = event.getFirstTagValue('p');
    repostedNoteAuthor = BelongsTo(
      ref,
      RequestFilter<Profile>(ids: {if (pTag != null) pTag}).toRequest(),
    );
  }
}

/// Generated partial model mixin for Repost
mixin PartialRepostMixin on RegularPartialModel<Repost> {
  /// Optional commentary on the repost
  String? get content => event.content.isEmpty ? null : event.content;

  /// Sets the repost commentary
  set content(String? value) => event.content = value ?? '';

  /// ID of the note being reposted
  String? get repostedNoteId => event.getFirstTagValue('e');

  /// Sets the reposted note ID
  set repostedNoteId(String? value) => event.setTagValue('e', value);

  /// Public key of the reposted note's author
  String? get repostedNotePubkey => event.getFirstTagValue('p');

  /// Sets the reposted note author's pubkey
  set repostedNotePubkey(String? value) => event.setTagValue('p', value);
}

/// Create and sign new repost events.
///
/// Example usage:
/// ```dart
/// final repost = await PartialRepost(content: 'Great content!', repostedNote: note).signWith(signer);
/// ```
class PartialRepost extends RegularPartialModel<Repost>
    with PartialRepostMixin {
  PartialRepost.fromMap(super.map) : super.fromMap();

  /// Creates a new repost of a note
  ///
  /// [content] - Optional commentary on the repost
  /// [repostedNote] - The note being reposted
  /// [repostedNoteAuthor] - The author of the original note
  /// [relayUrl] - Optional relay URL where the original can be found
  PartialRepost({
    String? content,
    Note? repostedNote,
    Profile? repostedNoteAuthor,
    String? relayUrl,
  }) {
    this.content = content;

    if (repostedNote != null) {
      // Add the required 'e' tag with the note ID and optional relay URL
      linkModel(repostedNote, relayUrl: relayUrl);
      // Set the 'p' tag with the note author's pubkey
      repostedNotePubkey = repostedNote.event.pubkey;
    }

    if (repostedNoteAuthor != null) {
      repostedNotePubkey = repostedNoteAuthor.pubkey;
    }
  }
}

part of models;

class Highlight extends RegularModel<Highlight> {
  String get content => event.content;

  late final BelongsTo<Note> referencedNote;
  late final BelongsTo<Article> referencedArticle;

  String? get referencedUrl => event.getFirstTagValue('r');
  String? get context => event.getFirstTagValue('context');

  /// The event ID being highlighted (from 'e' tag)
  String? get referencedEventId {
    final eTags = event.getTagSet('e');
    return eTags.isNotEmpty ? eTags.first[1] : null;
  }

  /// The addressable event being highlighted (from 'a' tag)
  String? get referencedAddress {
    final aTags = event.getTagSet('a');
    return aTags.isNotEmpty ? aTags.first[1] : null;
  }

  /// The pubkey of the original content author (from 'p' tag with 'author' role)
  String? get originalAuthorPubkey {
    final pTags = event.getTagSet('p');
    final authorTag = pTags.where((t) => t.length > 3 && t[3] == 'author');
    return authorTag.isNotEmpty ? authorTag.first[1] : null;
  }

  /// Whether this highlight references a Nostr event
  bool get isNostrHighlight =>
      referencedEventId != null || referencedAddress != null;

  /// Whether this highlight references an external URL
  bool get isUrlHighlight => referencedUrl != null;

  Highlight.fromMap(super.map, super.ref) : super.fromMap() {
    // Set up relationship to referenced note if it's a regular event
    referencedNote = BelongsTo(
      ref,
      referencedEventId != null
          ? RequestFilter<Note>(ids: {referencedEventId!}).toRequest()
          : null,
    );

    // Set up relationship to referenced article if it's an addressable event
    referencedArticle = BelongsTo(ref, Request.fromIds({?referencedAddress}));
  }
}

/// Generated partial model mixin for Highlight
mixin PartialHighlightMixin on RegularPartialModel<Highlight> {
  String? get content => event.content.isEmpty ? null : event.content;
  set content(String? value) => event.content = value ?? '';

  String? get referencedUrl => event.getFirstTagValue('r');
  set referencedUrl(String? value) => event.setTagValue('r', value);

  String? get context => event.getFirstTagValue('context');
  set context(String? value) => event.setTagValue('context', value);
}

class PartialHighlight extends RegularPartialModel<Highlight>
    with PartialHighlightMixin {
  PartialHighlight.fromMap(super.map) : super.fromMap();

  /// Create a highlight for a Nostr note
  PartialHighlight.fromNote(
    String content,
    Note referencedNote, {
    String? context,
    DateTime? createdAt,
  }) {
    event.content = content;
    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    linkModel(referencedNote);

    if (context != null) {
      event.addTagValue('context', context);
    }

    // Add original author tag if the note has an author
    if (referencedNote.event.pubkey.isNotEmpty) {
      event.tags.add(['p', referencedNote.event.pubkey, '', 'author']);
    }
  }

  /// Create a highlight for a Nostr article
  PartialHighlight.fromArticle(
    String content,
    Article referencedArticle, {
    String? context,
    DateTime? createdAt,
  }) {
    event.content = content;
    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    linkModel(referencedArticle);

    if (context != null) {
      event.addTagValue('context', context);
    }

    // Add original author tag if the article has an author
    if (referencedArticle.event.pubkey.isNotEmpty) {
      event.tags.add(['p', referencedArticle.event.pubkey, '', 'author']);
    }
  }

  /// Create a highlight for an external URL
  PartialHighlight.fromUrl(
    String content,
    String url, {
    String? context,
    String? authorPubkey,
    DateTime? createdAt,
  }) {
    event.content = content;
    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    event.addTagValue('r', url);

    if (context != null) {
      event.addTagValue('context', context);
    }

    if (authorPubkey != null) {
      event.tags.add(['p', authorPubkey, '', 'author']);
    }
  }

  /// Create a general highlight with manual configuration
  PartialHighlight(
    String content, {
    String? referencedEventId,
    String? referencedAddress,
    String? url,
    String? context,
    String? authorPubkey,
    DateTime? createdAt,
  }) {
    event.content = content;
    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    if (referencedEventId != null) {
      event.addTagValue('e', referencedEventId);
    }

    if (referencedAddress != null) {
      event.addTagValue('a', referencedAddress);
    }

    if (url != null) {
      event.addTagValue('r', url);
    }

    if (context != null) {
      event.addTagValue('context', context);
    }

    if (authorPubkey != null) {
      event.tags.add(['p', authorPubkey, '', 'author']);
    }
  }
}

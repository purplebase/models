part of models;

/// A highlight event (kind 9802) for highlighting portions of content.
///
/// Highlights allow users to emphasize specific parts of articles, notes,
/// or other content. They can include context and reference the original content.
class Highlight extends RegularModel<Highlight> {
  /// The highlighted text content
  String get content => event.content;

  late final BelongsTo<Note> referencedNote;
  late final BelongsTo<Article> referencedArticle;

  /// URL being highlighted (for external content)
  String? get referencedUrl => event.getFirstTagValue('r');

  /// Additional context for the highlight
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
  /// The highlighted text content
  String? get content => event.content.isEmpty ? null : event.content;

  /// Sets the highlighted text content
  set content(String? value) => event.content = value ?? '';

  /// URL being highlighted (for external content)
  String? get referencedUrl => event.getFirstTagValue('r');

  /// Sets the referenced URL
  set referencedUrl(String? value) => event.setTagValue('r', value);

  /// Additional context for the highlight
  String? get context => event.getFirstTagValue('context');

  /// Sets the highlight context
  set context(String? value) => event.setTagValue('context', value);
}

/// Create and sign new highlight events.
///
/// Example usage:
/// ```dart
/// final highlight = await PartialHighlight.fromNote('highlighted text', note).signWith(signer);
/// ```
class PartialHighlight extends RegularPartialModel<Highlight>
    with PartialHighlightMixin {
  PartialHighlight.fromMap(super.map) : super.fromMap();

  /// Creates a highlight for a Nostr note
  ///
  /// [content] - The text being highlighted
  /// [referencedNote] - The note containing the highlighted text
  /// [context] - Optional additional context
  /// [createdAt] - Optional creation timestamp
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

  /// Creates a highlight for a Nostr article
  ///
  /// [content] - The text being highlighted
  /// [referencedArticle] - The article containing the highlighted text
  /// [context] - Optional additional context
  /// [createdAt] - Optional creation timestamp
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

  /// Creates a highlight for an external URL
  ///
  /// [content] - The text being highlighted
  /// [url] - The URL where the content was found
  /// [context] - Optional additional context
  /// [authorPubkey] - Optional pubkey of the original author
  /// [createdAt] - Optional creation timestamp
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

  /// Creates a general highlight with manual configuration
  ///
  /// [content] - The text being highlighted
  /// [referencedEventId] - Optional event ID being highlighted
  /// [referencedAddress] - Optional addressable event being highlighted
  /// [url] - Optional external URL being highlighted
  /// [context] - Optional additional context
  /// [authorPubkey] - Optional pubkey of the original author
  /// [createdAt] - Optional creation timestamp
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

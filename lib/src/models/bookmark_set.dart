part of models;

/// A named collection of bookmarks (Kind 30003) from NIP-51.
///
/// **Encryption Strategy:**
/// - Content is plaintext BEFORE signing
/// - Content is encrypted DURING signing (in prepareForSigning)
/// - Content is always encrypted AFTER signing (locally and on relays)
/// - To read: must explicitly decrypt using signer
///
/// Bookmark sets allow users to organize their saved content into collections
/// like "Read Later", "Favorites", or "Resources". Supports both encrypted
/// (private) and public bookmarks.
class BookmarkSet extends ParameterizableReplaceableModel<BookmarkSet>
    with EncryptableModel<BookmarkSet> {
  BookmarkSet.fromMap(super.map, super.ref) : super.fromMap();

  /// The name of this bookmark set
  String? get name => event.getFirstTagValue('name');

  /// The description of this bookmark set
  String? get description => event.getFirstTagValue('description');

  /// Public event IDs that are bookmarked
  Set<String> get bookmarkedEvents => event.getTagSetValues('e');

  /// Public addressable event IDs (a tags) that are bookmarked
  Set<String> get bookmarkedAddressableEvents => event.getTagSetValues('a');

  /// Public URLs that are bookmarked
  Set<String> get bookmarkedUrls => event.getTagSetValues('r');

  /// Public hashtags that are bookmarked
  Set<String> get bookmarkedHashtags => event.getTagSetValues('t');

  /// Get private bookmarks (content is encrypted - will fail if not decrypted first)
  List<dynamic> get privateBookmarks {
    if (content.isEmpty) return [];
    try {
      final decoded = jsonDecode(content);
      return decoded is List ? decoded : [];
    } catch (e) {
      return [];
    }
  }

  @override
  String getEncryptionPubkey() {
    // Self-encryption: encrypt to own pubkey
    return event.pubkey;
  }

  /// Whether this bookmark set has any bookmarks (public or private)
  bool get hasBookmarks =>
      bookmarkedEvents.isNotEmpty ||
      bookmarkedAddressableEvents.isNotEmpty ||
      bookmarkedUrls.isNotEmpty ||
      bookmarkedHashtags.isNotEmpty ||
      content.isNotEmpty;
}

/// Create and manage named bookmark collections.
///
/// Example usage:
/// ```dart
/// // Create a public bookmark set
/// final bookmarkSet = PartialBookmarkSet(
///   name: 'Tech Articles',
///   identifier: 'tech-articles',
/// );
/// bookmarkSet.addBookmarkedEvent('event123...');
/// bookmarkSet.addBookmarkedUrl('https://example.com');
///
/// // Create a private bookmark set with encrypted content
/// final privateBookmarks = PartialBookmarkSet.withEncryptedBookmarks(
///   name: 'Private Saves',
///   identifier: 'private',
///   bookmarks: [
///     ['e', 'event123...'],
///     ['a', '30023:pubkey:identifier'],
///     ['r', 'https://secret.com'],
///   ],
/// );
/// await privateBookmarks.signWith(signer);
/// ```
class PartialBookmarkSet
    extends ParameterizableReplaceablePartialModel<BookmarkSet>
    with EncryptablePartialModel<BookmarkSet> {
  PartialBookmarkSet.fromMap(super.map) : super.fromMap();

  /// The name of this bookmark set
  String? get name => event.getFirstTagValue('name');
  set name(String? value) => event.setTagValue('name', value);

  /// The description of this bookmark set
  String? get description => event.getFirstTagValue('description');
  set description(String? value) => event.setTagValue('description', value);

  /// Public event IDs that are bookmarked
  Set<String> get bookmarkedEvents => event.getTagSetValues('e');
  set bookmarkedEvents(Set<String> value) => event.setTagValues('e', value);
  void addBookmarkedEvent(String? eventId) => event.addTagValue('e', eventId);
  void removeBookmarkedEvent(String? eventId) =>
      event.removeTagWithValue('e', eventId);

  /// Public addressable event IDs (a tags) that are bookmarked
  Set<String> get bookmarkedAddressableEvents => event.getTagSetValues('a');
  set bookmarkedAddressableEvents(Set<String> value) =>
      event.setTagValues('a', value);
  void addBookmarkedAddressableEvent(String? addressableId) =>
      event.addTagValue('a', addressableId);
  void removeBookmarkedAddressableEvent(String? addressableId) =>
      event.removeTagWithValue('a', addressableId);

  /// Public URLs that are bookmarked
  Set<String> get bookmarkedUrls => event.getTagSetValues('r');
  set bookmarkedUrls(Set<String> value) => event.setTagValues('r', value);
  void addBookmarkedUrl(String? url) => event.addTagValue('r', url);
  void removeBookmarkedUrl(String? url) => event.removeTagWithValue('r', url);

  /// Public hashtags that are bookmarked
  Set<String> get bookmarkedHashtags => event.getTagSetValues('t');
  set bookmarkedHashtags(Set<String> value) => event.setTagValues('t', value);
  void addBookmarkedHashtag(String? hashtag) => event.addTagValue('t', hashtag);
  void removeBookmarkedHashtag(String? hashtag) =>
      event.removeTagWithValue('t', hashtag);

  /// Raw encrypted content (for advanced use)
  String? get encryptedContent => event.content.isEmpty ? null : event.content;
  set encryptedContent(String? value) => event.content = value ?? '';

  /// Creates a new bookmark set
  ///
  /// [name] - Display name for this bookmark set
  /// [identifier] - Unique identifier (auto-generated if not provided)
  /// [description] - Optional description
  /// [bookmarkedEvents] - Initial set of event IDs to bookmark
  /// [bookmarkedUrls] - Initial set of URLs to bookmark
  /// [bookmarkedHashtags] - Initial set of hashtags to bookmark
  PartialBookmarkSet({
    required String name,
    String? identifier,
    String? description,
    Set<String>? bookmarkedEvents,
    Set<String>? bookmarkedAddressableEvents,
    Set<String>? bookmarkedUrls,
    Set<String>? bookmarkedHashtags,
  }) {
    this.name = name;
    event.setTagValue('d', identifier ?? _generateIdentifier());
    if (description != null) this.description = description;
    if (bookmarkedEvents != null) this.bookmarkedEvents = bookmarkedEvents;
    if (bookmarkedAddressableEvents != null) {
      this.bookmarkedAddressableEvents = bookmarkedAddressableEvents;
    }
    if (bookmarkedUrls != null) this.bookmarkedUrls = bookmarkedUrls;
    if (bookmarkedHashtags != null) {
      this.bookmarkedHashtags = bookmarkedHashtags;
    }
  }

  /// Creates a bookmark set with encrypted (private) bookmarks
  ///
  /// [name] - Display name for this bookmark set
  /// [identifier] - Unique identifier (auto-generated if not provided)
  /// [description] - Optional description
  /// [bookmarks] - List of bookmark tags to encrypt (e.g., [['e', 'id'], ['r', 'url']])
  ///
  /// The bookmarks will be encrypted using NIP-44 when signed.
  PartialBookmarkSet.withEncryptedBookmarks({
    required String name,
    String? identifier,
    String? description,
    required List<List<String>> bookmarks,
  }) {
    this.name = name;
    event.setTagValue('d', identifier ?? _generateIdentifier());
    if (description != null) this.description = description;
    setContent(bookmarks);
  }

  /// Creates a bookmark set with pre-encrypted content
  ///
  /// [name] - Display name for this bookmark set
  /// [identifier] - Unique identifier (auto-generated if not provided)
  /// [description] - Optional description
  /// [encryptedContent] - Already encrypted bookmark content
  PartialBookmarkSet.encrypted({
    required String name,
    String? identifier,
    String? description,
    required String encrypted,
  }) {
    this.name = name;
    event.setTagValue('d', identifier ?? _generateIdentifier());
    if (description != null) this.description = description;
    event.content = encrypted;
  }

  /// Set private bookmarks (plaintext until signing, then encrypted).
  void setPrivateBookmarks(List<List<String>> bookmarks) =>
      setContent(bookmarks);

  @override
  String getEncryptionPubkey(Signer signer) => signer.pubkey; // Encrypt to self

  String _generateIdentifier() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}

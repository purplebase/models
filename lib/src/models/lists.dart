part of models;

// ======================================================================
// NIP-65: Relay List Metadata
// ======================================================================

/// A user's preferred relay configuration for reading and writing content.
///
/// Relay lists help the network understand where to find a user's content
/// and where to send them mentions. Users typically maintain 2-4 relays
/// for optimal performance and redundancy.
class RelayListMetadata extends ReplaceableModel<RelayListMetadata> {
  RelayListMetadata.fromMap(super.map, super.ref) : super.fromMap();

  /// All relay URLs configured by this user
  Set<String> get allRelayUrls => event.getTagSetValues('r');

  /// Relays where the user publishes content
  Set<String> get writeRelays {
    return event
        .getTagSet('r')
        .where((tag) => tag.length < 3 || tag[2] != 'read')
        .map((tag) => tag[1])
        .toSet();
  }

  /// Relays where the user reads mentions and replies
  Set<String> get readRelays {
    return event
        .getTagSet('r')
        .where((tag) => tag.length < 3 || tag[2] != 'write')
        .map((tag) => tag[1])
        .toSet();
  }

  /// Whether this user has configured any relays
  bool get hasRelays => allRelayUrls.isNotEmpty;
}

/// Manage your relay configuration for optimal network performance.
///
/// Example usage:
/// ```dart
/// final relayList = await PartialRelayListMetadata()
///   ..addWriteRelay('wss://relay.damus.io')
///   ..addReadRelay('wss://nos.lol')
///   ..addRelay('wss://relay.snort.social'); // both read and write
/// await relayList.signWith(signer);
/// ```
class PartialRelayListMetadata
    extends ReplaceablePartialModel<RelayListMetadata> {
  PartialRelayListMetadata.fromMap(super.map) : super.fromMap();

  /// All relay URLs configured by this user
  Set<String> get allRelayUrls => event.getTagSetValues('r');

  /// Sets all relay URLs (clears existing configuration)
  set allRelayUrls(Set<String> value) => event.setTagValues('r', value);

  /// Adds a relay for both reading and writing
  void addRelay(String relayUrl) => event.addTag('r', [relayUrl]);

  /// Adds a relay specifically for writing content
  void addWriteRelay(String relayUrl) =>
      event.addTag('r', [relayUrl, '', 'write']);

  /// Adds a relay specifically for reading mentions
  void addReadRelay(String relayUrl) =>
      event.addTag('r', [relayUrl, '', 'read']);

  /// Removes a relay from the configuration
  void removeRelay(String relayUrl) {
    event.tags.removeWhere(
      (tag) => tag.length > 1 && tag[0] == 'r' && tag[1] == relayUrl,
    );
  }

  /// Creates a new relay list configuration
  PartialRelayListMetadata({
    Set<String>? writeRelays,
    Set<String>? readRelays,
    Set<String>? bothRelays,
  }) {
    if (writeRelays != null) {
      for (final relay in writeRelays) {
        addWriteRelay(relay);
      }
    }
    if (readRelays != null) {
      for (final relay in readRelays) {
        addReadRelay(relay);
      }
    }
    if (bothRelays != null) {
      for (final relay in bothRelays) {
        addRelay(relay);
      }
    }
  }
}

// ======================================================================
// NIP-51: User Lists (Replaceable)
// ======================================================================

/// A list of users that should be hidden from your feeds.
///
/// Mute lists help users curate their experience by filtering out
/// unwanted content from specific accounts without blocking them entirely.
class MuteList extends ReplaceableModel<MuteList> {
  MuteList.fromMap(super.map, super.ref) : super.fromMap();

  /// Public keys of muted users
  Set<String> get mutedUsers => event.getTagSetValues('p');

  /// IDs of muted content
  Set<String> get mutedContent => event.getTagSetValues('e');

  /// Muted hashtags or keywords
  Set<String> get mutedKeywords => event.getTagSetValues('word');

  /// Whether this user has muted anyone
  bool get hasMutedUsers => mutedUsers.isNotEmpty;
}

/// Manage your personal mute list for a better social experience.
class PartialMuteList extends ReplaceablePartialModel<MuteList> {
  PartialMuteList.fromMap(super.map) : super.fromMap();

  /// Public keys of muted users
  Set<String> get mutedUsers => event.getTagSetValues('p');
  set mutedUsers(Set<String> value) => event.setTagValues('p', value);
  void addMutedUser(String? pubkey) => event.addTagValue('p', pubkey);
  void removeMutedUser(String? pubkey) => event.removeTagWithValue('p', pubkey);

  /// IDs of muted content
  Set<String> get mutedContent => event.getTagSetValues('e');
  set mutedContent(Set<String> value) => event.setTagValues('e', value);
  void addMutedContent(String? eventId) => event.addTagValue('e', eventId);
  void removeMutedContent(String? eventId) =>
      event.removeTagWithValue('e', eventId);

  /// Muted hashtags or keywords
  Set<String> get mutedKeywords => event.getTagSetValues('word');
  set mutedKeywords(Set<String> value) => event.setTagValues('word', value);
  void addMutedKeyword(String? keyword) => event.addTagValue('word', keyword);
  void removeMutedKeyword(String? keyword) =>
      event.removeTagWithValue('word', keyword);

  PartialMuteList();
}

/// A list of important content you want to highlight in your profile.
///
/// Pin lists allow users to showcase their best or most important
/// posts prominently on their profile or in special feeds.
class PinList extends ReplaceableModel<PinList> {
  PinList.fromMap(super.map, super.ref) : super.fromMap();

  /// IDs of pinned content
  Set<String> get pinnedContent => event.getTagSetValues('e');

  /// Whether this user has pinned any content
  bool get hasPinnedContent => pinnedContent.isNotEmpty;
}

/// Highlight your best content with a pin list.
class PartialPinList extends ReplaceablePartialModel<PinList> {
  PartialPinList.fromMap(super.map) : super.fromMap();

  /// IDs of pinned content
  Set<String> get pinnedContent => event.getTagSetValues('e');
  set pinnedContent(Set<String> value) => event.setTagValues('e', value);
  void addPinnedContent(String? eventId) => event.addTagValue('e', eventId);
  void removePinnedContent(String? eventId) =>
      event.removeTagWithValue('e', eventId);

  PartialPinList();
}

/// A personal collection of saved content for later reading.
///
/// Bookmark lists help users save interesting posts, articles, or other
/// content they want to revisit without cluttering their main feeds.
class BookmarkList extends ReplaceableModel<BookmarkList> {
  BookmarkList.fromMap(super.map, super.ref) : super.fromMap();

  /// IDs of bookmarked content
  Set<String> get bookmarkedContent => event.getTagSetValues('e');

  /// URLs of bookmarked web content
  Set<String> get bookmarkedUrls => event.getTagSetValues('r');

  /// Whether this user has any bookmarks
  bool get hasBookmarks =>
      bookmarkedContent.isNotEmpty || bookmarkedUrls.isNotEmpty;
}

/// Save content for later with your personal bookmark collection.
class PartialBookmarkList extends ReplaceablePartialModel<BookmarkList> {
  PartialBookmarkList.fromMap(super.map) : super.fromMap();

  /// IDs of bookmarked content
  Set<String> get bookmarkedContent => event.getTagSetValues('e');
  set bookmarkedContent(Set<String> value) => event.setTagValues('e', value);
  void addBookmarkedContent(String? eventId) => event.addTagValue('e', eventId);
  void removeBookmarkedContent(String? eventId) =>
      event.removeTagWithValue('e', eventId);

  /// URLs of bookmarked web content
  Set<String> get bookmarkedUrls => event.getTagSetValues('r');
  set bookmarkedUrls(Set<String> value) => event.setTagValues('r', value);
  void addBookmarkedUrl(String? url) => event.addTagValue('r', url);
  void removeBookmarkedUrl(String? url) => event.removeTagWithValue('r', url);

  PartialBookmarkList();
}

// ======================================================================
// NIP-51: Parameterizable Sets
// ======================================================================

/// Named collections of users for organized following.
///
/// Follow sets allow users to create custom groups of people they follow,
/// like "Developers", "Friends", or "News Sources" for better content curation.
class FollowSets extends ParameterizableReplaceableModel<FollowSets> {
  FollowSets.fromMap(super.map, super.ref) : super.fromMap();

  /// The name of this follow set
  String? get name => event.getFirstTagValue('name');

  /// Public keys of users in this follow set
  Set<String> get followedUsers => event.getTagSetValues('p');

  /// Whether this set has any followers
  bool get hasFollowers => followedUsers.isNotEmpty;
}

/// Create organized collections of people you follow.
class PartialFollowSets
    extends ParameterizableReplaceablePartialModel<FollowSets> {
  PartialFollowSets.fromMap(super.map) : super.fromMap();

  /// The name of this follow set
  String? get name => event.getFirstTagValue('name');
  set name(String? value) => event.setTagValue('name', value);

  /// Public keys of users in this follow set
  Set<String> get followedUsers => event.getTagSetValues('p');
  set followedUsers(Set<String> value) => event.setTagValues('p', value);
  void addFollowedUser(String? pubkey) => event.addTagValue('p', pubkey);
  void removeFollowedUser(String? pubkey) =>
      event.removeTagWithValue('p', pubkey);

  /// Creates a new follow set
  ///
  /// [name] - Display name for this set
  /// [identifier] - Unique identifier (auto-generated if not provided)
  /// [followedUsers] - Initial set of users to follow
  PartialFollowSets({
    required String name,
    String? identifier,
    Set<String>? followedUsers,
  }) {
    this.name = name;
    event.setTagValue('d', identifier ?? _generateIdentifier());
    if (followedUsers != null) this.followedUsers = followedUsers;
  }

  String _generateIdentifier() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}

/// An app curation set event (kind 30267) for organizing applications.
///
/// App curation sets provide curated lists of applications,
/// similar to app stores or recommendation lists.
class AppCurationSet extends ParameterizableReplaceableModel<AppCurationSet> {
  AppCurationSet.fromMap(super.map, super.ref) : super.fromMap();

  /// The name of this app curation set
  String? get name => event.getFirstTagValue('name');

  /// Application identifiers in this curation set
  Set<String> get appIdentifiers => event.getTagSetValues('a');

  /// Whether this set contains any applications
  bool get hasApps => appIdentifiers.isNotEmpty;
}

/// Curate collections of applications for discovery and recommendation.
class PartialAppCurationSet
    extends ParameterizableReplaceablePartialModel<AppCurationSet> {
  PartialAppCurationSet.fromMap(super.map) : super.fromMap();

  /// The name of this app curation set
  String? get name => event.getFirstTagValue('name');
  set name(String? value) => event.setTagValue('name', value);

  /// Application identifiers in this curation set
  Set<String> get appIdentifiers => event.getTagSetValues('a');
  set appIdentifiers(Set<String> value) => event.setTagValues('a', value);
  void addAppIdentifier(String? identifier) =>
      event.addTagValue('a', identifier);
  void removeAppIdentifier(String? identifier) =>
      event.removeTagWithValue('a', identifier);

  /// Creates a new app curation set
  PartialAppCurationSet({
    String? name,
    String? identifier,
    Set<String>? appIdentifiers,
  }) {
    if (name != null) this.name = name;
    event.setTagValue('d', identifier ?? _generateIdentifier());
    if (appIdentifiers != null) this.appIdentifiers = appIdentifiers;
  }

  String _generateIdentifier() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}

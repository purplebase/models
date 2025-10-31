part of models;

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

part of models;

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

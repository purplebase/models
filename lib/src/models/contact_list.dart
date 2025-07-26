part of models;

/// A contact list event (kind 3) representing a user's following list.
///
/// Contact lists contain the public keys of users that someone follows.
/// They are replaceable events, so newer contact lists replace older ones.
class ContactList extends ReplaceableModel<ContactList> {
  late final HasMany<Profile> following;
  late final HasMany<Profile> followers;

  ContactList.fromMap(super.map, super.ref) : super.fromMap() {
    following = HasMany(
      ref,
      RequestFilter<Profile>(authors: followingPubkeys).toRequest(),
    );
    followers = HasMany(ref, null);
  }

  /// Set of public keys being followed
  Set<String> get followingPubkeys => event.getTagSetValues('p');
}

/// Generated partial model mixin for ContactList
mixin PartialContactListMixin on ReplaceablePartialModel<ContactList> {
  /// Set of public keys being followed
  Set<String> get followingPubkeys => event.getTagSetValues('p');

  /// Sets the followed public keys
  set followingPubkeys(Set<String> value) => event.setTagValues('p', value);

  /// Adds a public key to the following list
  void addFollowingPubkey(String? value) => event.addTagValue('p', value);

  /// Removes a public key from the following list
  void removeFollowingPubkey(String? value) =>
      event.removeTagWithValue('p', value);
}

/// Create and sign new contact list events.
///
/// Example usage:
/// ```dart
/// final contactList = await PartialContactList(followPubkeys: {'pubkey1'}).signWith(signer);
/// ```
class PartialContactList extends ReplaceablePartialModel<ContactList>
    with PartialContactListMixin {
  PartialContactList.fromMap(super.map) : super.fromMap();

  /// Creates a new contact list with specified follows
  ///
  /// [followPubkeys] - Set of public keys to follow
  PartialContactList({Set<String> followPubkeys = const {}}) {
    for (final pubkey in followPubkeys) {
      addFollowingPubkey(pubkey);
    }
  }

  /// Adds a profile to the following list
  void addFollow(Profile profile) => addFollowingPubkey(profile.pubkey);

  /// Removes a profile from the following list
  void removeFollow(Profile profile) => removeFollowingPubkey(profile.pubkey);
}

part of models;

class ContactList extends ReplaceableEvent<ContactList> {
  late final HasMany<Profile> following;
  late final HasMany<Profile> followers;
  ContactList.fromMap(super.map, super.ref) : super.fromMap() {
    following =
        HasMany(ref, RequestFilter(kinds: {0}, authors: followingPubkeys));
    followers = HasMany(ref, null);
  }
  Set<String> get followingPubkeys => internal.getTagSetValues('p');
}

class PartialContactList extends ReplaceablePartialEvent<ContactList> {
  PartialContactList({List<String> followPubkeys = const []}) {
    addFollowPubkeys(followPubkeys);
  }

  void addFollow(Profile profile) => internal.addTagValue('p', profile.pubkey);
  void addFollowPubkeys(List<String> pubkeys) =>
      internal.addTagValues('p', pubkeys);
  void removeFollow(Profile profile) =>
      internal.removeTagWithValue('p', profile.pubkey);
  void removeFollowPubkey(String pubkey) =>
      internal.removeTagWithValue('p', pubkey);
}

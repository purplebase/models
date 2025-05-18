part of models;

class ContactList extends ReplaceableModel<ContactList> {
  late final HasMany<Profile> following;
  late final HasMany<Profile> followers;
  ContactList.fromMap(super.map, super.ref) : super.fromMap() {
    following = HasMany(ref, RequestFilter(authors: followingPubkeys));
    followers = HasMany(ref, null);
  }
  Set<String> get followingPubkeys => event.getTagSetValues('p');
}

class PartialContactList extends ReplaceablePartialModel<ContactList> {
  PartialContactList({Set<String> followPubkeys = const {}}) {
    addFollowPubkeys(followPubkeys);
  }

  void addFollow(Profile profile) => event.addTagValue('p', profile.pubkey);
  void addFollowPubkeys(Set<String> pubkeys) =>
      event.addTagValues('p', pubkeys);
  void removeFollow(Profile profile) =>
      event.removeTagWithValue('p', profile.pubkey);
  void removeFollowPubkey(String pubkey) =>
      event.removeTagWithValue('p', pubkey);
}

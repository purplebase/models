part of models;

@GeneratePartialModel()
class ContactList extends ReplaceableModel<ContactList> {
  late final HasMany<Profile> following;
  late final HasMany<Profile> followers;
  ContactList.fromMap(super.map, super.ref) : super.fromMap() {
    following = HasMany(
        ref, RequestFilter<Profile>(authors: followingPubkeys).toRequest());
    followers = HasMany(ref, null);
  }
  Set<String> get followingPubkeys => event.getTagSetValues('p');
}

class PartialContactList extends ReplaceablePartialModel<ContactList>
    with PartialContactListMixin {
  PartialContactList({Set<String> followPubkeys = const {}}) {
    for (final pubkey in followPubkeys) {
      addFollowingPubkey(pubkey);
    }
  }

  void addFollow(Profile profile) => addFollowingPubkey(profile.pubkey);
  void removeFollow(Profile profile) => removeFollowingPubkey(profile.pubkey);
}

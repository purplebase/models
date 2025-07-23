part of models;

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

  Set<String> get followingPubkeys => event.getTagSetValues('p');
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for ContactList
mixin PartialContactListMixin on ReplaceablePartialModel<ContactList> {
  Set<String> get followingPubkeys => event.getTagSetValues('p');
  set followingPubkeys(Set<String> value) => event.setTagValues('p', value);
  void addFollowingPubkey(String? value) => event.addTagValue('p', value);
  void removeFollowingPubkey(String? value) =>
      event.removeTagWithValue('p', value);
}

class PartialContactList extends ReplaceablePartialModel<ContactList>
    with PartialContactListMixin {
  PartialContactList.fromMap(super.map) : super.fromMap();

  PartialContactList({Set<String> followPubkeys = const {}}) {
    for (final pubkey in followPubkeys) {
      addFollowingPubkey(pubkey);
    }
  }

  void addFollow(Profile profile) => addFollowingPubkey(profile.pubkey);
  void removeFollow(Profile profile) => removeFollowingPubkey(profile.pubkey);
}

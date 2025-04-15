import 'package:models/models.dart';

class ContactList extends ReplaceableEvent<ContactList> {
  late final HasMany<Profile> following;
  late final HasMany<Profile> followers;
  ContactList.fromMap(super.map, super.ref) : super.fromMap() {
    following =
        HasMany(ref, RequestFilter(kinds: {0}, authors: followingPubkeys));
    // TODO: Implement known followers
    followers = HasMany(ref, null);
  }
  Set<String> get followingPubkeys => internal.getTagSetValues('p');
}

class PartialContactList extends ReplaceablePartialEvent<ContactList> {
  void addFollow(Profile profile) => internal.addTagValue('p', profile.pubkey);
  void addFollowPubkey(String pubkey) => internal.addTagValue('p', pubkey);
  void removeFollow(Profile profile) =>
      internal.removeTagWithValue('p', profile.pubkey);
  void removeFollowPubkey(String pubkey) =>
      internal.removeTagWithValue('p', pubkey);
}

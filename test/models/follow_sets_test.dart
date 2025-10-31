import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    storage =
        container.read(storageNotifierProvider.notifier)
            as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.cancel();
    await storage.clear();
    container.dispose();
  });

  group('FollowSets', () {
    test('basic follow set creation', () {
      const user1 =
          'user123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';
      const user2 =
          'user789abcdef123456789abcdef123456789abcdef123456789abcdef123456';

      final followSet = PartialFollowSets(
        name: 'Tech Influencers',
        identifier: 'tech-influencers',
        followedUsers: {user1, user2},
      ).dummySign(nielPubkey);

      expect(followSet.name, 'Tech Influencers');
      expect(followSet.identifier, 'tech-influencers');
      expect(followSet.followedUsers, {user1, user2});
    });

    test('event kind and structure', () {
      const testUser =
          'test456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final followSet = PartialFollowSets(
        name: 'Test Set',
        identifier: 'test-set',
        followedUsers: {testUser},
      ).dummySign(nielPubkey);

      expect(followSet.event.kind, 30000);
      expect(followSet.event.getFirstTagValue('d'), 'test-set');
      expect(followSet.event.getFirstTagValue('name'), 'Test Set');

      // Check p tags for followed users
      final pTags = followSet.event.getTagSet('p');
      expect(pTags.length, 1);
      expect(pTags.first[1], testUser);
    });

    test('partial model methods', () {
      final partial = PartialFollowSets(name: 'Test', identifier: 'test');

      // Test user management
      partial.addFollowedUser('user1');
      partial.addFollowedUser('user2');
      expect(partial.followedUsers, {'user1', 'user2'});

      partial.removeFollowedUser('user1');
      expect(partial.followedUsers, {'user2'});
    });
  });
}

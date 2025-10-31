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

  group('MuteList', () {
    test('basic mute list creation', () {
      const user1 =
          'user123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';
      const user2 =
          'user789abcdef123456789abcdef123456789abcdef123456789abcdef123456';

      final partial = PartialMuteList();
      partial.mutedUsers = {user1, user2};
      partial.mutedKeywords = {'spam', 'bitcoin'};
      final muteList = partial.dummySign(nielPubkey);

      expect(muteList.mutedUsers, {user1, user2});
      expect(muteList.mutedKeywords, {'spam', 'bitcoin'});
    });

    test('event kind and structure', () {
      const testUser =
          'test456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final partial = PartialMuteList();
      partial.mutedUsers = {testUser};
      partial.mutedKeywords = {'test'};
      final muteList = partial.dummySign(nielPubkey);

      expect(muteList.event.kind, 10000);

      // Check p tags for muted users
      final pTags = muteList.event.getTagSet('p');
      expect(pTags.length, 1);
      expect(pTags.first[1], testUser);

      // Check word tags
      final wordTags = muteList.event.getTagSet('word');
      expect(wordTags.length, 1);
      expect(wordTags.first[1], 'test');
    });

    test('partial model methods', () {
      final partial = PartialMuteList();

      // Test user management
      partial.addMutedUser('user1');
      partial.addMutedUser('user2');
      expect(partial.mutedUsers, {'user1', 'user2'});

      partial.removeMutedUser('user1');
      expect(partial.mutedUsers, {'user2'});

      // Test keyword management
      partial.addMutedKeyword('spam');
      partial.addMutedKeyword('scam');
      expect(partial.mutedKeywords, {'spam', 'scam'});

      partial.removeMutedKeyword('spam');
      expect(partial.mutedKeywords, {'scam'});
    });
  });
}

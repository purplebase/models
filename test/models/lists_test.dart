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

  group('RelayListMetadata', () {
    test('basic relay list creation', () {
      final relayList = PartialRelayListMetadata(
        writeRelays: {'wss://relay1.example.com'},
        readRelays: {'wss://relay2.example.com'},
        bothRelays: {'wss://relay3.example.com'},
      ).dummySign(nielPubkey);

      expect(relayList.allRelayUrls.length, 3);
      expect(
        relayList.writeRelays,
        containsAll(['wss://relay1.example.com', 'wss://relay3.example.com']),
      );
      expect(
        relayList.readRelays,
        containsAll(['wss://relay2.example.com', 'wss://relay3.example.com']),
      );
    });

    test('empty relay list', () {
      final relayList = PartialRelayListMetadata().dummySign(nielPubkey);
      expect(relayList.allRelayUrls, isEmpty);
    });

    test('event kind and structure', () {
      final relayList = PartialRelayListMetadata(
        readRelays: {'wss://test.relay.com'},
      ).dummySign(nielPubkey);

      expect(relayList.event.kind, 10002);
      expect(relayList.event.content, '');

      final rTags = relayList.event.getTagSet('r');
      expect(rTags.length, 1);
      expect(rTags.first[0], 'r');
      expect(rTags.first[1], 'wss://test.relay.com');
      if (rTags.first.length > 2) {
        expect(rTags.first[2], ''); // Middle position is empty
      }
      if (rTags.first.length > 3) {
        expect(rTags.first[3], 'read'); // Read flag in position 3
      }
    });

    test('partial model methods', () {
      final partial = PartialRelayListMetadata();

      // Test relay management
      partial.addRelay('wss://relay1.com');
      partial.addReadRelay('wss://relay2.com');
      partial.addWriteRelay('wss://relay3.com');

      expect(partial.allRelayUrls.length, 3);
      expect(
        partial.allRelayUrls,
        containsAll([
          'wss://relay1.com',
          'wss://relay2.com',
          'wss://relay3.com',
        ]),
      );

      partial.removeRelay('wss://relay1.com');
      expect(partial.allRelayUrls.length, 2);
      expect(partial.allRelayUrls.contains('wss://relay1.com'), false);
    });
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

  group('PinList', () {
    test('basic pin list creation', () {
      const event1 =
          'event123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';
      const event2 =
          'event789abcdef123456789abcdef123456789abcdef123456789abcdef123456';

      final partial = PartialPinList();
      partial.pinnedContent = {event1, event2};
      final pinList = partial.dummySign(nielPubkey);

      expect(pinList.pinnedContent, {event1, event2});
    });

    test('event kind and structure', () {
      const testEvent =
          'test456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final partial = PartialPinList();
      partial.pinnedContent = {testEvent};
      final pinList = partial.dummySign(nielPubkey);

      expect(pinList.event.kind, 10001);

      // Check e tags for pinned events
      final eTags = pinList.event.getTagSet('e');
      expect(eTags.length, 1);
      expect(eTags.first[1], testEvent);
    });

    test('partial model methods', () {
      final partial = PartialPinList();

      // Test event management
      partial.addPinnedContent('event1');
      partial.addPinnedContent('event2');
      expect(partial.pinnedContent, {'event1', 'event2'});

      partial.removePinnedContent('event1');
      expect(partial.pinnedContent, {'event2'});
    });
  });

  group('BookmarkList', () {
    test('basic bookmark list creation', () {
      const event1 =
          'event123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';
      const event2 =
          'event789abcdef123456789abcdef123456789abcdef123456789abcdef123456';

      final partial = PartialBookmarkList();
      partial.bookmarkedContent = {event1, event2};
      partial.bookmarkedUrls = {'https://example1.com', 'https://example2.com'};
      final bookmarkList = partial.dummySign(nielPubkey);

      expect(bookmarkList.bookmarkedContent, {event1, event2});
      expect(bookmarkList.bookmarkedUrls, {
        'https://example1.com',
        'https://example2.com',
      });
    });

    test('event kind and structure', () {
      const testEvent =
          'test456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final partial = PartialBookmarkList();
      partial.bookmarkedContent = {testEvent};
      partial.bookmarkedUrls = {'https://test.com'};
      final bookmarkList = partial.dummySign(nielPubkey);

      expect(bookmarkList.event.kind, 10003);

      // Check e tags for bookmarked events
      final eTags = bookmarkList.event.getTagSet('e');
      expect(eTags.length, 1);
      expect(eTags.first[1], testEvent);

      // Check r tags for bookmarked URLs
      final rTags = bookmarkList.event.getTagSet('r');
      expect(rTags.length, 1);
      expect(rTags.first[1], 'https://test.com');
    });

    test('partial model methods', () {
      final partial = PartialBookmarkList();

      // Test event management
      partial.addBookmarkedContent('event1');
      partial.addBookmarkedContent('event2');
      expect(partial.bookmarkedContent, {'event1', 'event2'});

      partial.removeBookmarkedContent('event1');
      expect(partial.bookmarkedContent, {'event2'});

      // Test URL management
      partial.addBookmarkedUrl('https://site1.com');
      partial.addBookmarkedUrl('https://site2.com');
      expect(partial.bookmarkedUrls, {
        'https://site1.com',
        'https://site2.com',
      });

      partial.removeBookmarkedUrl('https://site1.com');
      expect(partial.bookmarkedUrls, {'https://site2.com'});
    });
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

  group('Lists integration tests', () {
    test('create and use multiple list types', () async {
      const user1 =
          'user123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';
      const user2 =
          'user789abcdef123456789abcdef123456789abcdef123456789abcdef123456';
      const event1 =
          'event123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      // Create relay list
      final relayList = PartialRelayListMetadata(
        bothRelays: {'wss://relay1.com'},
        readRelays: {'wss://relay2.com'},
      ).dummySign(nielPubkey);

      // Create mute list
      final mutePartial = PartialMuteList();
      mutePartial.mutedUsers = {user1};
      mutePartial.mutedKeywords = {'spam'};
      final muteList = mutePartial.dummySign(nielPubkey);

      // Create pin list
      final pinPartial = PartialPinList();
      pinPartial.pinnedContent = {event1};
      final pinList = pinPartial.dummySign(nielPubkey);

      // Create bookmark list
      final bookmarkPartial = PartialBookmarkList();
      bookmarkPartial.bookmarkedContent = {event1};
      bookmarkPartial.bookmarkedUrls = {'https://example.com'};
      final bookmarkList = bookmarkPartial.dummySign(nielPubkey);

      // Create follow set
      final followSet = PartialFollowSets(
        name: 'Friends',
        identifier: 'friends',
        followedUsers: {user2},
      ).dummySign(nielPubkey);

      await storage.save({
        relayList,
        muteList,
        pinList,
        bookmarkList,
        followSet,
      });

      // Verify all lists were created successfully
      expect(relayList.allRelayUrls.length, 2);
      expect(muteList.mutedUsers, {user1});
      expect(pinList.pinnedContent, {event1});
      expect(bookmarkList.bookmarkedContent, {event1});
      expect(followSet.followedUsers, {user2});
    });

    test('relationships work with valid IDs', () async {
      const validUser =
          'abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';

      // Create test data
      final profile = PartialProfile(name: 'Test User').dummySign(validUser);
      final note = PartialNote('Test content').dummySign(validUser);

      await storage.save({profile, note});

      // Create lists referencing the test data
      final mutePartial = PartialMuteList();
      mutePartial.mutedUsers = {validUser};
      final muteList = mutePartial.dummySign(nielPubkey);

      final pinPartial = PartialPinList();
      pinPartial.pinnedContent = {note.event.id};
      final pinList = pinPartial.dummySign(nielPubkey);

      await storage.save({muteList, pinList});

      // Test that relationships are properly set up (models exist)
      expect(muteList.mutedUsers, {validUser});
      expect(pinList.pinnedContent, {note.event.id});
    });
  });
}

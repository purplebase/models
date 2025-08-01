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

  group('AppCurationSet', () {
    test('basic app curation set creation', () {
      final appCurationSet = PartialAppCurationSet(
        name: 'Developer Tools',
        identifier: 'dev-tools-2024',
      ).dummySign(nielPubkey);

      expect(appCurationSet.name, 'Developer Tools');
      expect(appCurationSet.identifier, 'dev-tools-2024');
    });

    test('name falls back to identifier when not set', () {
      final appCurationSet = PartialAppCurationSet(
        identifier: 'my-apps',
      ).dummySign(nielPubkey);

      expect(appCurationSet.name, 'my-apps');
    });

    test('event kind and structure', () {
      final appCurationSet = PartialAppCurationSet(
        name: 'Test Apps',
        identifier: 'test-apps',
      ).dummySign(nielPubkey);

      expect(appCurationSet.event.kind, 30267);
      expect(appCurationSet.event.getFirstTagValue('d'), 'test-apps');
      expect(appCurationSet.event.getFirstTagValue('name'), 'Test Apps');
    });

    test('addApp method adds a-tags correctly', () {
      final partial = PartialAppCurationSet(
        name: 'My Apps',
        identifier: 'my-apps',
      );

      const appId1 =
          '32267:abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:app1';
      const appId2 =
          '32267:efgh1234567890abcdef1234567890abcdef1234567890abcdef1234567890cd:app2';

      partial.addApp(appId1);
      partial.addApp(appId2);

      final appCurationSet = partial.dummySign(nielPubkey);

      // Check a tags for app IDs
      final aTags = appCurationSet.event.getTagSet('a');
      expect(aTags.length, 2);

      final appIds = aTags.map((tag) => tag[1]).toSet();
      expect(appIds, {appId1, appId2});
    });

    test('apps relationship queries correctly', () async {
      // Create test apps
      final app1Partial = PartialApp()
        ..name = 'Test App 1'
        ..event.setTagValue('d', 'test-app-1');
      final app1 = app1Partial.dummySign(nielPubkey);

      final app2Partial = PartialApp()
        ..name = 'Test App 2'
        ..event.setTagValue('d', 'test-app-2');
      final app2 = app2Partial.dummySign(nielPubkey);

      await storage.save({app1, app2});

      // Create app curation set with these apps
      final partial = PartialAppCurationSet(
        name: 'Test Collection',
        identifier: 'test-collection',
      );

      partial.addApp(app1.id);
      partial.addApp(app2.id);

      final appCurationSet = partial.dummySign(nielPubkey);
      await storage.save({appCurationSet});

      // Test the apps relationship
      final curationSets = await storage.query(
        Request<AppCurationSet>.fromIds({appCurationSet.id}),
      );
      expect(curationSets.length, 1);
      final retrievedSet = curationSets.first;
      expect(retrievedSet.apps.length, 2);

      final appNames = retrievedSet.apps
          .toList()
          .map((app) => app.name)
          .toSet();
      expect(appNames, {'Test App 1', 'Test App 2'});
    });

    test('automatic identifier generation', () async {
      final appCurationSet1 = PartialAppCurationSet(
        name: 'Apps 1',
      ).dummySign(nielPubkey);

      // Ensure different timestamps by waiting a brief moment
      await Future.delayed(Duration(milliseconds: 1));

      final appCurationSet2 = PartialAppCurationSet(
        name: 'Apps 2',
      ).dummySign(nielPubkey);

      expect(appCurationSet1.identifier, isNotEmpty);
      expect(appCurationSet2.identifier, isNotEmpty);
      expect(
        appCurationSet1.identifier,
        isNot(equals(appCurationSet2.identifier)),
      );
    });

    test('linkModelById works for apps', () {
      final partial = PartialAppCurationSet(
        name: 'Linked Apps',
        identifier: 'linked-apps',
      );

      const appId =
          '32267:abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:myapp';
      partial.linkModelById(appId, isReplaceable: true);

      final appCurationSet = partial.dummySign(nielPubkey);

      // Check that a-tag was added
      final aTags = appCurationSet.event.getTagSet('a');
      expect(aTags.length, 1);
      expect(aTags.first[1], appId);
    });

    test('app can find curation sets it belongs to', () async {
      // Create test app
      final appPartial = PartialApp()
        ..name = 'My App'
        ..event.setTagValue('d', 'my-app');
      final app = appPartial.dummySign(nielPubkey);
      await storage.save({app});

      // Create curation sets that include this app
      final curationSet1Partial = PartialAppCurationSet(
        name: 'Tools',
        identifier: 'tools',
      );
      curationSet1Partial.addApp(app.id);
      final curationSet1 = curationSet1Partial.dummySign(nielPubkey);

      final curationSet2Partial = PartialAppCurationSet(
        name: 'Favorites',
        identifier: 'favorites',
      );
      curationSet2Partial.addApp(app.id);
      final curationSet2 = curationSet2Partial.dummySign(nielPubkey);

      await storage.save({curationSet1, curationSet2});

      // Test the reverse relationship
      final apps = await storage.query(Request<App>.fromIds({app.id}));
      expect(apps.length, 1);
      final retrievedApp = apps.first;
      expect(retrievedApp.appCurationSets.length, 2);

      final curationSetNames = retrievedApp.appCurationSets
          .toList()
          .map((set) => set.name)
          .toSet();
      expect(curationSetNames, {'Tools', 'Favorites'});
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

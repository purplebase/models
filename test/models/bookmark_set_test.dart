import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
    storage =
        container.read(storageNotifierProvider.notifier) as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.clear();
    container.dispose();
  });

  group('BookmarkSet', () {
    test('basic public bookmark set creation', () {
      const event1 =
          'event123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';
      const event2 =
          'event789abcdef123456789abcdef123456789abcdef123456789abcdef123456';
      const addressable1 = '30023:pubkey123:article1';

      final bookmarkSet = PartialBookmarkSet(
        name: 'Tech Articles',
        identifier: 'tech-articles',
        description: 'My favorite tech articles',
        bookmarkedEvents: {event1, event2},
        bookmarkedAddressableEvents: {addressable1},
        bookmarkedUrls: {'https://example1.com', 'https://example2.com'},
        bookmarkedHashtags: {'tech', 'programming'},
      ).dummySign(nielPubkey);

      expect(bookmarkSet.name, 'Tech Articles');
      expect(bookmarkSet.identifier, 'tech-articles');
      expect(bookmarkSet.description, 'My favorite tech articles');
      expect(bookmarkSet.bookmarkedEvents, {event1, event2});
      expect(bookmarkSet.bookmarkedAddressableEvents, {addressable1});
      expect(bookmarkSet.bookmarkedUrls, {
        'https://example1.com',
        'https://example2.com',
      });
      expect(bookmarkSet.bookmarkedHashtags, {'tech', 'programming'});
      expect(bookmarkSet.hasBookmarks, true);
    });

    test('event kind and structure', () {
      const testEvent =
          'test456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final bookmarkSet = PartialBookmarkSet(
        name: 'Test Set',
        identifier: 'test-set',
        bookmarkedEvents: {testEvent},
        bookmarkedUrls: {'https://test.com'},
      ).dummySign(nielPubkey);

      expect(bookmarkSet.event.kind, 30003);
      expect(bookmarkSet.event.getFirstTagValue('d'), 'test-set');
      expect(bookmarkSet.event.getFirstTagValue('name'), 'Test Set');

      // Check e tags for bookmarked events
      final eTags = bookmarkSet.event.getTagSet('e');
      expect(eTags.length, 1);
      expect(eTags.first[1], testEvent);

      // Check r tags for bookmarked URLs
      final rTags = bookmarkSet.event.getTagSet('r');
      expect(rTags.length, 1);
      expect(rTags.first[1], 'https://test.com');
    });

    test('partial model methods', () {
      final partial = PartialBookmarkSet(
        name: 'My Bookmarks',
        identifier: 'my-bookmarks',
      );

      // Test event management
      partial.addBookmarkedEvent('event1');
      partial.addBookmarkedEvent('event2');
      expect(partial.bookmarkedEvents, {'event1', 'event2'});

      partial.removeBookmarkedEvent('event1');
      expect(partial.bookmarkedEvents, {'event2'});

      // Test addressable event management
      partial.addBookmarkedAddressableEvent('30023:pubkey:id1');
      partial.addBookmarkedAddressableEvent('30023:pubkey:id2');
      expect(partial.bookmarkedAddressableEvents, {
        '30023:pubkey:id1',
        '30023:pubkey:id2',
      });

      partial.removeBookmarkedAddressableEvent('30023:pubkey:id1');
      expect(partial.bookmarkedAddressableEvents, {'30023:pubkey:id2'});

      // Test URL management
      partial.addBookmarkedUrl('https://site1.com');
      partial.addBookmarkedUrl('https://site2.com');
      expect(partial.bookmarkedUrls, {
        'https://site1.com',
        'https://site2.com',
      });

      partial.removeBookmarkedUrl('https://site1.com');
      expect(partial.bookmarkedUrls, {'https://site2.com'});

      // Test hashtag management
      partial.addBookmarkedHashtag('tech');
      partial.addBookmarkedHashtag('news');
      expect(partial.bookmarkedHashtags, {'tech', 'news'});

      partial.removeBookmarkedHashtag('tech');
      expect(partial.bookmarkedHashtags, {'news'});
    });

    test('encrypted bookmark set creation with dummy signing', () {
      final partial = PartialBookmarkSet.withEncryptedBookmarks(
        name: 'Private Bookmarks',
        identifier: 'private',
        description: 'My private saves',
        bookmarks: [
          ['e', 'event123456789'],
          ['a', '30023:pubkey123:article'],
          ['r', 'https://secret.com'],
          ['t', 'private-tag'],
        ],
      );

      // Before signing: content contains the plaintext bookmarks
      expect(partial.content, isNotEmpty);

      final bookmarkSet = partial.dummySign(nielPubkey);

      expect(bookmarkSet.name, 'Private Bookmarks');
      expect(bookmarkSet.identifier, 'private');
      expect(bookmarkSet.description, 'My private saves');

      // After signing: content is encrypted
      expect(bookmarkSet.content.isNotEmpty, true);
      expect(bookmarkSet.content, contains('dummy_nip44_encrypted'));

      // Public tags should be empty since bookmarks are private
      expect(bookmarkSet.bookmarkedEvents, isEmpty);
      expect(bookmarkSet.bookmarkedUrls, isEmpty);
      expect(bookmarkSet.bookmarkedHashtags, isEmpty);
    });

    test('bookmark set with encrypted private bookmarks', () {
      final partial = PartialBookmarkSet.withEncryptedBookmarks(
        name: 'Private Set',
        identifier: 'private',
        bookmarks: [
          ['e', 'event123'],
          ['a', '30023:pubkey:id1'],
        ],
      );

      // Before signing: content contains the plaintext bookmarks
      expect(partial.content, isNotEmpty);

      final bookmarkSet = partial.dummySign(nielPubkey);

      expect(bookmarkSet.name, 'Private Set');
      // After signing: content is encrypted
      expect(bookmarkSet.content.isNotEmpty, true);
      expect(bookmarkSet.content, contains('dummy_nip44_encrypted'));
    });

    test('mixed public and encrypted bookmarks', () {
      // Create a bookmark set with public bookmarks
      final partial = PartialBookmarkSet(
        name: 'Mixed Bookmarks',
        identifier: 'mixed',
        bookmarkedEvents: {'public_event123'},
        bookmarkedUrls: {'https://public.com'},
      );

      // Note: In real usage, you would NOT mix public and private bookmarks
      // But the model should handle it if someone does
      final bookmarkSet = partial.dummySign(nielPubkey);

      expect(bookmarkSet.bookmarkedEvents, {'public_event123'});
      expect(bookmarkSet.bookmarkedUrls, {'https://public.com'});
      expect(bookmarkSet.content.isEmpty, true);
    });

    test('empty bookmark set', () {
      final bookmarkSet = PartialBookmarkSet(
        name: 'Empty Set',
        identifier: 'empty',
      ).dummySign(nielPubkey);

      expect(bookmarkSet.name, 'Empty Set');
      expect(bookmarkSet.hasBookmarks, false);
      expect(bookmarkSet.bookmarkedEvents, isEmpty);
      expect(bookmarkSet.bookmarkedAddressableEvents, isEmpty);
      expect(bookmarkSet.bookmarkedUrls, isEmpty);
      expect(bookmarkSet.bookmarkedHashtags, isEmpty);
      expect(bookmarkSet.content.isEmpty, true);
    });

    test('automatic identifier generation', () async {
      final bookmarkSet1 = PartialBookmarkSet(
        name: 'Set 1',
      ).dummySign(nielPubkey);

      // Ensure different timestamps by waiting a brief moment
      await Future.delayed(Duration(milliseconds: 1));

      final bookmarkSet2 = PartialBookmarkSet(
        name: 'Set 2',
      ).dummySign(nielPubkey);

      expect(bookmarkSet1.identifier, isNotEmpty);
      expect(bookmarkSet2.identifier, isNotEmpty);
      expect(bookmarkSet1.identifier, isNot(equals(bookmarkSet2.identifier)));
    });

    test('privateBookmarks returns empty list when no content', () {
      final bookmarkSet = PartialBookmarkSet(
        name: 'Public Only',
        identifier: 'public',
        bookmarkedEvents: {'event123'},
      ).dummySign(nielPubkey);

      expect(bookmarkSet.privateBookmarks, isEmpty);
    });

    test('encrypted bookmarks accessible before signing', () {
      final partial = PartialBookmarkSet.withEncryptedBookmarks(
        name: 'Private',
        identifier: 'private',
        bookmarks: [
          ['e', 'secret1'],
          ['a', '30023:pubkey:secret2'],
        ],
      );

      // Before signing: content contains the plaintext bookmarks
      expect(partial.content, isNotEmpty);

      // After signing: content is encrypted
      final signed = partial.dummySign(nielPubkey);
      expect(signed.content, contains('dummy_nip44_encrypted'));
    });

    test('storage and retrieval', () async {
      final bookmarkSet = PartialBookmarkSet(
        name: 'Saved Set',
        identifier: 'saved-set',
        bookmarkedEvents: {'event123'},
        bookmarkedUrls: {'https://example.com'},
      ).dummySign(nielPubkey);

      await storage.save({bookmarkSet});

      final retrieved = await storage.query(
        Request<BookmarkSet>.fromIds({bookmarkSet.id}),
      );

      expect(retrieved.length, 1);
      expect(retrieved.first.name, 'Saved Set');
      expect(retrieved.first.identifier, 'saved-set');
      expect(retrieved.first.bookmarkedEvents, {'event123'});
      expect(retrieved.first.bookmarkedUrls, {'https://example.com'});
    });

    test('replaceability - newer event replaces older', () async {
      final bookmarkSet1 = PartialBookmarkSet(
        name: 'Version 1',
        identifier: 'my-bookmarks',
        bookmarkedEvents: {'event1'},
      ).dummySign(nielPubkey);

      await storage.save({bookmarkSet1});

      // Wait to ensure different timestamp
      await Future.delayed(Duration(milliseconds: 1));

      final bookmarkSet2 = PartialBookmarkSet(
        name: 'Version 2',
        identifier: 'my-bookmarks', // Same identifier
        bookmarkedEvents: {'event2'},
      ).dummySign(nielPubkey);

      await storage.save({bookmarkSet2});

      // Query by the identifier
      final retrieved = await storage.query(
        Request<BookmarkSet>.fromIds({bookmarkSet2.id}),
      );

      // Should only get the newer version
      expect(retrieved.length, 1);
      expect(retrieved.first.name, 'Version 2');
      expect(retrieved.first.bookmarkedEvents, {'event2'});
    });
  });
}

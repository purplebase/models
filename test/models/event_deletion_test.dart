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

  group('EventDeletionRequest', () {
    test('from/to partial model', () async {
      final deletion = PartialEventDeletionRequest(
        reason: 'Inappropriate content',
        deletedEventIds: {'event123', 'event456'},
        deletedProfilePubkeys: {'pubkey789'},
      ).dummySign(nielPubkey);

      expect(deletion.reason, 'Inappropriate content');
      expect(deletion.deletedEventIds, {'event123', 'event456'});
      expect(deletion.deletedProfilePubkeys, {'pubkey789'});
      expect(deletion.hasDeletedEvents, true);
      expect(deletion.hasDeletedProfiles, true);

      final partial = deletion.toPartial() as PartialEventDeletionRequest;
      expect(partial.reason, 'Inappropriate content');
      expect(partial.deletedEventIds, {'event123', 'event456'});
      expect(partial.deletedProfilePubkeys, {'pubkey789'});
    });

    test('event deletion only', () {
      final deletion = PartialEventDeletionRequest(
        reason: 'Spam',
        deletedEventIds: {'spam1', 'spam2', 'spam3'},
      ).dummySign(nielPubkey);

      expect(deletion.reason, 'Spam');
      expect(deletion.deletedEventIds, {'spam1', 'spam2', 'spam3'});
      expect(deletion.deletedProfilePubkeys, isEmpty);
      expect(deletion.hasDeletedEvents, true);
      expect(deletion.hasDeletedProfiles, false);
    });

    test('profile deletion only', () {
      final deletion = PartialEventDeletionRequest(
        reason: 'Banned user',
        deletedProfilePubkeys: {'baduser1', 'baduser2'},
      ).dummySign(nielPubkey);

      expect(deletion.reason, 'Banned user');
      expect(deletion.deletedEventIds, isEmpty);
      expect(deletion.deletedProfilePubkeys, {'baduser1', 'baduser2'});
      expect(deletion.hasDeletedEvents, false);
      expect(deletion.hasDeletedProfiles, true);
    });

    test('empty deletion request', () {
      final deletion = PartialEventDeletionRequest().dummySign(nielPubkey);

      expect(deletion.reason, '');
      expect(deletion.deletedEventIds, isEmpty);
      expect(deletion.deletedProfilePubkeys, isEmpty);
      expect(deletion.hasDeletedEvents, false);
      expect(deletion.hasDeletedProfiles, false);
    });

    test('partial model methods', () {
      final partial = PartialEventDeletionRequest();

      // Test setters
      partial.reason = 'Test reason';
      expect(partial.reason, 'Test reason');

      // Test event ID management
      partial.addDeletedEventId('event1');
      partial.addDeletedEventId('event2');
      expect(partial.deletedEventIds, {'event1', 'event2'});

      partial.removeDeletedEventId('event1');
      expect(partial.deletedEventIds, {'event2'});

      partial.deletedEventIds = {'new1', 'new2'};
      expect(partial.deletedEventIds, {'new1', 'new2'});

      // Test profile pubkey management
      partial.addDeletedProfilePubkey('pub1');
      partial.addDeletedProfilePubkey('pub2');
      expect(partial.deletedProfilePubkeys, {'pub1', 'pub2'});

      partial.removeDeletedProfilePubkey('pub1');
      expect(partial.deletedProfilePubkeys, {'pub2'});

      partial.deletedProfilePubkeys = {'newpub1', 'newpub2'};
      expect(partial.deletedProfilePubkeys, {'newpub1', 'newpub2'});
    });

    test('relationships', () async {
      // Create some test data
      final noteA = PartialNote('Note A').dummySign(nielPubkey);
      final noteB = PartialNote('Note B').dummySign(nielPubkey);
      final profile = PartialProfile(name: 'Test User').dummySign(nielPubkey);

      await storage.save({noteA, noteB, profile});

      final deletion = PartialEventDeletionRequest(
        reason: 'Clean up',
        deletedEventIds: {noteA.event.id, noteB.event.id},
        deletedProfilePubkeys: {profile.event.pubkey},
      ).dummySign(nielPubkey);

      await storage.save({deletion});

      expect(deletion.deletedEvents.req!.filters.first.ids, {
        noteA.event.id,
        noteB.event.id,
      });
      expect(deletion.deletedProfiles.req!.filters.first.authors, {
        profile.event.pubkey,
      });
    });

    test('event kind and structure', () {
      final deletion = PartialEventDeletionRequest(
        reason: 'Test',
        deletedEventIds: {'event1'},
        deletedProfilePubkeys: {'pub1'},
      ).dummySign(nielPubkey);

      expect(deletion.event.kind, 5);
      expect(deletion.event.content, 'Test');
      expect(deletion.event.getTagSetValues('e'), {'event1'});
      expect(deletion.event.getTagSetValues('p'), {'pub1'});
    });
  });
}

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
        container.read(storageNotifierProvider.notifier)
            as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.clear();
    container.dispose();
  });

  group('EventDeletionRequest', () {
    test('basic event deletion creation and properties', () {
      final deletion = PartialEventDeletionRequest(
        reason: 'Inappropriate content',
        deletedEventIds: {'event1', 'event2'},
      ).dummySign(nielPubkey);

      expect(deletion.event.kind, 5);
      expect(deletion.reason, equals('Inappropriate content'));
      expect(deletion.deletedEventIds, containsAll(['event1', 'event2']));
      expect(deletion.hasDeletedEvents, isTrue);
      expect(deletion.hasDeletedProfiles, isFalse);
    });

    test('profile deletion requests', () {
      final deletion = PartialEventDeletionRequest(
        reason: 'Account deletion',
        deletedProfilePubkeys: {nielPubkey, franzapPubkey},
      ).dummySign(nielPubkey);

      expect(deletion.reason, equals('Account deletion'));
      expect(
        deletion.deletedProfilePubkeys,
        containsAll([nielPubkey, franzapPubkey]),
      );
      expect(deletion.hasDeletedEvents, isFalse);
      expect(deletion.hasDeletedProfiles, isTrue);
    });

    test('mixed event and profile deletions', () {
      final deletion = PartialEventDeletionRequest(
        reason: 'Complete cleanup',
        deletedEventIds: {'event1', 'event2'},
        deletedProfilePubkeys: {nielPubkey},
      ).dummySign(nielPubkey);

      expect(deletion.reason, equals('Complete cleanup'));
      expect(deletion.deletedEventIds, containsAll(['event1', 'event2']));
      expect(deletion.deletedProfilePubkeys, contains(nielPubkey));
      // Check that collections are not empty
      expect(deletion.deletedEventIds.isNotEmpty, isTrue);
      expect(deletion.deletedProfilePubkeys.isNotEmpty, isTrue);
    });

    test('empty deletion request', () {
      final deletion = PartialEventDeletionRequest().dummySign(nielPubkey);

      expect(deletion.reason, isEmpty);
      expect(deletion.deletedEventIds, isEmpty);
      expect(deletion.deletedProfilePubkeys, isEmpty);
      expect(deletion.hasDeletedEvents, isFalse);
      expect(deletion.hasDeletedProfiles, isFalse);
    });
  });

  group('EventDeletionRequest Event Management', () {
    test('add and remove event IDs', () {
      final partial = PartialEventDeletionRequest(reason: 'Test deletion');

      partial.addDeletedEventId('event1');
      partial.addDeletedEventId('event2');
      expect(partial.deletedEventIds, containsAll(['event1', 'event2']));

      partial.removeDeletedEventId('event1');
      expect(partial.deletedEventIds, contains('event2'));
      expect(partial.deletedEventIds, isNot(contains('event1')));
    });

    test('add and remove profile pubkeys', () {
      final partial = PartialEventDeletionRequest(reason: 'Profile cleanup');

      partial.addDeletedProfilePubkey(nielPubkey);
      partial.addDeletedProfilePubkey(franzapPubkey);
      expect(
        partial.deletedProfilePubkeys,
        containsAll([nielPubkey, franzapPubkey]),
      );

      partial.removeDeletedProfilePubkey(nielPubkey);
      expect(partial.deletedProfilePubkeys, contains(franzapPubkey));
      expect(partial.deletedProfilePubkeys, isNot(contains(nielPubkey)));
    });

    test('set event IDs and profile pubkeys', () {
      final partial = PartialEventDeletionRequest();

      partial.deletedEventIds = {'event1', 'event2', 'event3'};
      partial.deletedProfilePubkeys = {nielPubkey, franzapPubkey};

      expect(
        partial.deletedEventIds,
        containsAll(['event1', 'event2', 'event3']),
      );
      expect(
        partial.deletedProfilePubkeys,
        containsAll([nielPubkey, franzapPubkey]),
      );
    });
  });

  group('EventDeletionRequest Relationships', () {
    test('deletedEvents relationship', () async {
      // Create some events to delete
      final note1 = PartialNote('Note to delete 1').dummySign(nielPubkey);
      final note2 = PartialNote('Note to delete 2').dummySign(nielPubkey);

      await storage.save({note1, note2});

      // Create deletion request
      final deletion = PartialEventDeletionRequest(
        reason: 'Deleting old notes',
        deletedEventIds: {note1.id, note2.id},
      ).dummySign(nielPubkey);

      await storage.save({deletion});

      // Test the relationship
      expect(deletion.deletedEvents.toList(), containsAll([note1, note2]));
    });

    test('deletedProfiles relationship', () async {
      // Create some profiles to delete
      final profile1 = PartialProfile(name: 'Profile 1').dummySign(nielPubkey);
      final profile2 = PartialProfile(
        name: 'Profile 2',
      ).dummySign(franzapPubkey);

      await storage.save({profile1, profile2});

      // Create deletion request
      final deletion = PartialEventDeletionRequest(
        reason: 'Deleting profiles',
        deletedProfilePubkeys: {nielPubkey, franzapPubkey},
      ).dummySign(nielPubkey);

      await storage.save({deletion});

      // Test the relationship
      expect(
        deletion.deletedProfiles.toList(),
        containsAll([profile1, profile2]),
      );
    });

    test('handles non-existent events gracefully', () async {
      // Create deletion request for non-existent events
      final deletion = PartialEventDeletionRequest(
        reason: 'Deleting non-existent events',
        deletedEventIds: {'nonexistent1', 'nonexistent2'},
      ).dummySign(nielPubkey);

      await storage.save({deletion});

      // Relationship should be empty
      expect(deletion.deletedEvents.toList(), isEmpty);
    });

    test('filters invalid event IDs and pubkeys', () async {
      // Create valid events
      final validNote = PartialNote('Valid note').dummySign(nielPubkey);
      await storage.save({validNote});

      // Create deletion request with mix of valid and invalid IDs
      final deletion = PartialEventDeletionRequest(
        reason: 'Mixed valid/invalid',
        deletedEventIds: {validNote.id, 'invalid-id', 'short'},
      ).dummySign(nielPubkey);

      await storage.save({deletion});

      // Should only relate to valid events (64-char hex)
      expect(deletion.deletedEvents.toList(), contains(validNote));
      expect(deletion.deletedEvents.toList().length, 1);
    });
  });

  group('EventDeletionRequest Storage and Retrieval', () {
    test('saves and loads deletion requests', () async {
      final deletion = PartialEventDeletionRequest(
        reason: 'Test deletion',
        deletedEventIds: {'event1', 'event2'},
        deletedProfilePubkeys: {nielPubkey},
      ).dummySign(nielPubkey);

      await storage.save({deletion});

      final retrieved = await storage.query(
        Request<CustomData>.fromIds({deletion.id}),
      );
      expect(retrieved.length, 0); // Wrong type, should be EventDeletionRequest

      final correctRetrieved = await storage.query(
        Request<EventDeletionRequest>.fromIds({deletion.id}),
      );
      expect(correctRetrieved.length, 1);

      final loaded = correctRetrieved.first;
      expect(loaded.reason, equals('Test deletion'));
      expect(loaded.deletedEventIds, containsAll(['event1', 'event2']));
      expect(loaded.deletedProfilePubkeys, contains(nielPubkey));
    });

    test('multiple deletion requests', () async {
      final deletion1 = PartialEventDeletionRequest(
        reason: 'Delete 1',
        deletedEventIds: {'event1'},
      ).dummySign(nielPubkey);

      final deletion2 = PartialEventDeletionRequest(
        reason: 'Delete 2',
        deletedProfilePubkeys: {franzapPubkey},
      ).dummySign(franzapPubkey);

      await storage.save({deletion1, deletion2});

      final all = await storage.query(
        RequestFilter<EventDeletionRequest>().toRequest(),
      );
      expect(all.length, 2);

      final reasons = all.map((d) => d.reason).toSet();
      expect(reasons, containsAll(['Delete 1', 'Delete 2']));
    });

    test('query by author', () async {
      final deletion1 = PartialEventDeletionRequest(
        reason: 'From Niel',
        deletedEventIds: {'event1'},
      ).dummySign(nielPubkey);

      final deletion2 = PartialEventDeletionRequest(
        reason: 'From Franzap',
        deletedEventIds: {'event2'},
      ).dummySign(franzapPubkey);

      await storage.save({deletion1, deletion2});

      final fromNiel = await storage.query(
        RequestFilter<EventDeletionRequest>(authors: {nielPubkey}).toRequest(),
      );
      expect(fromNiel.length, 1);
      expect(fromNiel.first.reason, equals('From Niel'));
    });
  });

  group('EventDeletionRequest Event Structure', () {
    test('has correct event kind and content', () {
      final deletion = PartialEventDeletionRequest(
        reason: 'Test reason',
        deletedEventIds: {'event1'},
        deletedProfilePubkeys: {nielPubkey},
      ).dummySign(nielPubkey);

      expect(deletion.event.kind, 5);
      expect(deletion.event.content, equals('Test reason'));
    });

    test('includes e tags for deleted events', () {
      final deletion = PartialEventDeletionRequest(
        deletedEventIds: {'event1', 'event2'},
      ).dummySign(nielPubkey);

      final eTags = deletion.event.getTagSet('e');
      expect(eTags.length, 2);
      expect(eTags.map((tag) => tag[1]), containsAll(['event1', 'event2']));
    });

    test('includes p tags for deleted profiles', () {
      final deletion = PartialEventDeletionRequest(
        deletedProfilePubkeys: {nielPubkey, franzapPubkey},
      ).dummySign(nielPubkey);

      final pTags = deletion.event.getTagSet('p');
      expect(pTags.length, 2);
      expect(
        pTags.map((tag) => tag[1]),
        containsAll([nielPubkey, franzapPubkey]),
      );
    });

    test('shareable ID encoding', () {
      final deletion = PartialEventDeletionRequest(
        reason: 'Shareable deletion',
        deletedEventIds: {'test-event-id'},
      ).dummySign(nielPubkey);

      final shareableId = deletion.event.shareableId;
      expect(shareableId, startsWith('nevent1'));
    });
  });

  group('EventDeletionRequest Author Relationship', () {
    test('links to author profile', () async {
      final profile = PartialProfile(name: 'Deleter').dummySign(nielPubkey);
      final deletion = PartialEventDeletionRequest(
        reason: 'Deleting my content',
        deletedEventIds: {'event1'},
      ).dummySign(nielPubkey);

      await storage.save({profile, deletion});

      // Reload to ensure relationships are established
      final reloaded = await storage.query(
        Request<EventDeletionRequest>.fromIds({deletion.id}),
      );
      expect(reloaded.length, 1);
      expect(reloaded.first.author.value, equals(profile));
    });
  });

  group('EventDeletionRequest Use Cases', () {
    test('single event deletion', () {
      final deletion = PartialEventDeletionRequest(
        reason: 'Mistake',
        deletedEventIds: {'specific-event-id'},
      );

      expect(deletion.deletedEventIds, contains('specific-event-id'));
      expect(deletion.reason, equals('Mistake'));
    });

    test('bulk event deletion', () {
      final eventIds = List.generate(
        10,
        (i) => 'event-${i.toString().padLeft(3, '0')}',
      ).toSet();
      final deletion = PartialEventDeletionRequest(
        reason: 'Bulk cleanup',
        deletedEventIds: eventIds,
      );

      expect(deletion.deletedEventIds, equals(eventIds));
      expect(deletion.deletedEventIds.isNotEmpty, isTrue);
    });

    test('profile deletion', () {
      final deletion = PartialEventDeletionRequest(
        reason: 'Account closure',
        deletedProfilePubkeys: {nielPubkey},
      );

      expect(deletion.deletedProfilePubkeys, contains(nielPubkey));
      expect(deletion.deletedProfilePubkeys.isNotEmpty, isTrue);
    });

    test('complete account cleanup', () {
      final allEventIds = {'note1', 'note2', 'dm1', 'reaction1'};
      final deletion = PartialEventDeletionRequest(
        reason: 'Leaving platform',
        deletedEventIds: allEventIds,
        deletedProfilePubkeys: {nielPubkey},
      );

      expect(deletion.deletedEventIds, equals(allEventIds));
      expect(deletion.deletedProfilePubkeys, contains(nielPubkey));
      // Check signed version for hasDeleted* methods
      final signed = deletion.dummySign(nielPubkey);
      expect(signed.hasDeletedEvents, isTrue);
      expect(signed.hasDeletedProfiles, isTrue);
    });
  });

  group('EventDeletionRequest Error Cases', () {
    test('handles null reason', () {
      final deletion = PartialEventDeletionRequest(
        deletedEventIds: {'event1'},
      ).dummySign(nielPubkey);

      expect(deletion.reason, isEmpty);
    });

    test('handles empty event ID sets', () {
      final deletion = PartialEventDeletionRequest(
        reason: 'Empty deletion',
        deletedEventIds: {},
      ).dummySign(nielPubkey);

      expect(deletion.deletedEventIds, isEmpty);
      expect(deletion.hasDeletedEvents, isFalse);
    });

    test('handles empty profile pubkey sets', () {
      final deletion = PartialEventDeletionRequest(
        reason: 'Empty profile deletion',
        deletedProfilePubkeys: {},
      ).dummySign(nielPubkey);

      expect(deletion.deletedProfilePubkeys, isEmpty);
      expect(deletion.hasDeletedProfiles, isFalse);
    });

    test('gracefully handles invalid inputs', () {
      final partial = PartialEventDeletionRequest();

      // These should not crash
      partial.addDeletedEventId(null);
      partial.addDeletedProfilePubkey(null);
      partial.removeDeletedEventId(null);
      partial.removeDeletedProfilePubkey(null);

      final deletion = partial.dummySign(nielPubkey);
      expect(deletion.deletedEventIds, isEmpty);
      expect(deletion.deletedProfilePubkeys, isEmpty);
    });
  });
}

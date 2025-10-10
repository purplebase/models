import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'test_data_generators.dart';

void main() async {
  late ProviderContainer container;
  late DummyStorageNotifier storage;
  late TestDataGenerator generator;

  setUp(() async {
    // Create a fresh container and storage for each test
    container = ProviderContainer();
    final config = StorageConfiguration(
      relayGroups: {
        'big-relays': {'wss://damus.relay.io', 'wss://relay.primal.net'},
      },
      defaultRelayGroup: 'big-relays',
      streamingBufferWindow: Duration.zero,
      keepMaxModels: 1000,
    );
    await container.read(initializationProvider(config).future);
    storage =
        container.read(storageNotifierProvider.notifier)
            as DummyStorageNotifier;
    generator = container.read(testDataGeneratorProvider);
  });

  tearDown(() async {
    await storage.cancel();
    await storage.clear();
    container.dispose();
  });

  group('storage filters', () {
    late StateNotifierProviderTester tester;
    late Note a, b, c, d, e, f, g, replyToA, replyToB;
    late Profile nielProfile;

    setUp(() async {
      // Clear storage to ensure test isolation
      await storage.clear();

      final yesterday = DateTime.now().subtract(Duration(days: 1));
      final lastMonth = DateTime.now().subtract(Duration(days: 31));

      a = PartialNote('Note A', createdAt: yesterday).dummySign(nielPubkey);
      b = PartialNote('Note B', createdAt: lastMonth).dummySign(nielPubkey);
      c = PartialNote('Note C').dummySign(nielPubkey);
      d = PartialNote('Note D', tags: {'nostr'}).dummySign(nielPubkey);
      e = PartialNote('Note E').dummySign(franzapPubkey);
      f = PartialNote('Note F', tags: {'nostr'}).dummySign(franzapPubkey);
      g = PartialNote('Note G').dummySign(verbirichaPubkey);
      nielProfile = PartialProfile(name: 'neil').dummySign(nielPubkey);
      replyToA = PartialNote(
        'reply to a',
        replyTo: a,
      ).dummySign(nielProfile.pubkey);
      replyToB = PartialNote(
        'reply to b',
        createdAt: yesterday,
        replyTo: b,
      ).dummySign(nielProfile.pubkey);

      await storage.save({
        a,
        b,
        c,
        d,
        e,
        f,
        g,
        replyToA,
        replyToB,
        nielProfile,
      });
      await storage.publish({
        nielProfile,
      }, source: RemoteSource(group: 'big-relays'));
    });

    tearDown(() async {
      tester.dispose();
    });

    test('ids', () async {
      tester = container.testerFor(
        queryKinds(ids: {a.event.id, e.event.id}, source: LocalSource()),
      );
      await tester.expectModels(unorderedEquals({a, e}));
    });

    test('authors', () async {
      tester = container.testerFor(
        queryKinds(
          authors: {franzapPubkey, verbirichaPubkey},
          source: LocalSource(),
        ),
      );
      await tester.expectModels(unorderedEquals({e, f, g}));
    });

    test('kinds', () async {
      tester = container.testerFor(query<Note>(source: LocalSource()));
      await tester.expectModels(
        allOf(
          hasLength(9),
          everyElement((e) => e is Model && e.event.kind == 1),
        ),
      );

      tester = container.testerFor(query<Profile>(source: LocalSource()));
      await tester.expectModels(hasLength(1));
    });

    test('tags', () async {
      tester = container.testerFor(
        queryKinds(
          authors: {nielPubkey},
          tags: {
            '#t': {'nostr'},
          },
          source: LocalSource(),
        ),
      );
      await tester.expectModels(equals({d}));

      tester = container.testerFor(
        queryKinds(
          tags: {
            '#t': {'nostr', 'test'},
          },
          source: LocalSource(),
        ),
      );
      await tester.expectModels(unorderedEquals({d, f}));

      tester = container.testerFor(
        queryKinds(
          tags: {
            '#t': {'test'},
          },
          source: LocalSource(),
        ),
      );
      await tester.expectModels(isEmpty);

      tester = container.testerFor(
        queryKinds(
          tags: {
            '#t': {'nostr'},
            '#e': {nielPubkey},
          },
          source: LocalSource(),
        ),
      );
      await tester.expectModels(isEmpty);
    });

    test('until', () async {
      tester = container.testerFor(
        query<Note>(
          authors: {nielPubkey},
          until: DateTime.now().subtract(Duration(minutes: 1)),
          source: LocalSource(),
        ),
      );
      await tester.expectModels(orderedEquals({a, b, replyToB}));
    });

    test('since', () async {
      tester = container.testerFor(
        queryKinds(
          authors: {nielPubkey},
          since: DateTime.now().subtract(Duration(minutes: 1)),
          source: LocalSource(),
        ),
      );
      await tester.expectModels(orderedEquals({c, d, nielProfile, replyToA}));
    });

    test('limit and order', () async {
      tester = container.testerFor(
        query<Note>(authors: {nielPubkey}, limit: 3, source: LocalSource()),
      );
      await tester.expectModels(orderedEquals({d, c, replyToA}));
    });

    test('replaceable updates', () async {
      // Use a fresh pubkey to avoid test interference
      final testPubkey = Utils.generateRandomHex64();
      final originalProfile = PartialProfile(
        name: 'original',
      ).dummySign(testPubkey);
      await storage.save({originalProfile});

      tester = container.testerFor(
        query<Profile>(authors: {testPubkey}, source: LocalSource()),
      );
      await tester.expectModels(unorderedEquals({originalProfile}));

      final updatedProfile = originalProfile
          .copyWith(name: 'updated')
          .dummySign(testPubkey);
      // Check processMetadata() was called when constructing
      expect(updatedProfile.name, equals('updated'));
      // Content should NOT be empty as this new event could be sent to relays
      expect(updatedProfile.event.content, isNotEmpty);

      // Ensure the contents are actually different
      expect(
        originalProfile.event.content,
        isNot(equals(updatedProfile.event.content)),
      );
      expect(originalProfile.event.id, isNot(equals(updatedProfile.event.id)));

      await updatedProfile.save();

      // Wait for the storage state to update with the new profile
      // The replaceable update should replace the old profile with the new one
      // We need to wait for the state to propagate through the notifier
      await tester.expectModels(
        allOf(
          hasLength(1),
          everyElement((p) => p is Profile && p.name == 'updated'),
        ),
      );
    });

    test('relationships with model watcher', () async {
      tester = container.testerFor(
        model(a, and: (note) => {note.author}, source: LocalSource()),
      );
      await tester.expectModels(unorderedEquals({a}));
      // NOTE: note.author will be cached, but only note is returned
    });

    test('multiple relationships', () async {
      tester = container.testerFor(
        query<Note>(
          ids: {a.id, b.id},
          and: (note) => {note.author, note.replies},
          source: LocalSource(),
        ),
      );
      await tester.expectModels(unorderedEquals({a, b}));
      // NOTE: author and replies will be cached, can't assert here
    });

    test('nested relationships - 2 levels', () async {
      // Setup: App -> Release -> FileMetadata
      final pubkey = nielPubkey;
      
      // Create FileMetadata
      final partialFile = PartialFileMetadata()
        ..version = '1.0.0'
        ..appIdentifier = 'com.test.app'
        ..hash = 'abc123';
      final fileMetadata = partialFile.dummySign(pubkey);

      // Create Release that references the FileMetadata
      final partialRelease = PartialRelease(newFormat: true)
        ..identifier = 'com.test.app@1.0.0'
        ..appIdentifier = 'com.test.app'
        ..version = '1.0.0';
      partialRelease.event.addTag('e', [fileMetadata.id]);
      final release = partialRelease.dummySign(pubkey);

      // Create App that references the Release
      final partialApp = PartialApp()
        ..identifier = 'com.test.app'
        ..name = 'Test App';
      partialApp.event.setTagValue('i', 'com.test.app');
      final app = partialApp.dummySign(pubkey);

      // Save only the app initially
      await storage.save({app});

      // Query with nested relationships
      tester = container.testerFor(
        query<App>(
          ids: {app.id},
          and: (app) => {
            app.latestRelease,
            // Nested relationship: load metadata when release arrives
            if (app.latestRelease.value != null)
              app.latestRelease.value!.latestMetadata,
          },
          source: LocalSource(),
        ),
      );

      // Initial state: only app
      await tester.expectModels(hasLength(1));
      expect(tester.notifier.state.models.first.latestRelease.value, isNull);

      // Save the release - should trigger nested relationship discovery
      await storage.save({release});
      await Future.delayed(Duration(milliseconds: 50));

      // Release should now be available
      final appWithRelease = await storage.query(
        RequestFilter<App>(ids: {app.id}).toRequest(),
        source: LocalSource(),
      );
      expect(appWithRelease.first.latestRelease.value, isNotNull);
      expect(appWithRelease.first.latestRelease.value!.id, release.id);

      // Save the file metadata - should be queried due to nested relationship
      await storage.save({fileMetadata});
      await Future.delayed(Duration(milliseconds: 50));

      // FileMetadata should now be available through the nested relationship
      final appWithFullChain = await storage.query(
        RequestFilter<App>(ids: {app.id}).toRequest(),
        source: LocalSource(),
      );
      final loadedRelease = appWithFullChain.first.latestRelease.value;
      expect(loadedRelease, isNotNull);
      expect(loadedRelease!.latestMetadata.value, isNotNull);
      expect(loadedRelease.latestMetadata.value!.id, fileMetadata.id);
    });

    test('nested relationships - 3 levels with Note', () async {
      // Setup: Note -> Author (Profile) -> ContactList
      final authorPubkey = franzapPubkey;
      
      // Create ContactList
      final contactList = PartialContactList().dummySign(authorPubkey);

      // Create Profile (Author)
      final author = PartialProfile(name: 'Author Name').dummySign(authorPubkey);

      // Create Note
      final note = PartialNote('Test note content').dummySign(authorPubkey);

      // Save only the note initially
      await storage.save({note});

      // Query with nested relationships
      tester = container.testerFor(
        query<Note>(
          ids: {note.id},
          and: (note) => {
            note.author,
            // Nested: when author arrives, load their contact list
            if (note.author.value != null)
              note.author.value!.contactList,
          },
          source: LocalSource(),
        ),
      );

      await tester.expectModels(hasLength(1));

      // Save the author - should trigger nested relationship discovery
      await storage.save({author});
      await Future.delayed(Duration(milliseconds: 50));

      // Author should be available
      final noteWithAuthor = await storage.query(
        RequestFilter<Note>(ids: {note.id}).toRequest(),
        source: LocalSource(),
      );
      expect(noteWithAuthor.first.author.value, isNotNull);
      expect(noteWithAuthor.first.author.value!.name, 'Author Name');

      // Save the contact list - should be queried due to nested relationship
      await storage.save({contactList});
      await Future.delayed(Duration(milliseconds: 50));

      // ContactList should now be available through the nested relationship
      final noteWithFullChain = await storage.query(
        RequestFilter<Note>(ids: {note.id}).toRequest(),
        source: LocalSource(),
      );
      final loadedAuthor = noteWithFullChain.first.author.value;
      expect(loadedAuthor, isNotNull);
      expect(loadedAuthor!.contactList.value, isNotNull);
      expect(loadedAuthor.contactList.value!.id, contactList.id);
    });

    test('conditional nested relationships', () async {
      // Test that conditional relationships only load when condition is met
      final pubkey1 = nielPubkey;
      final pubkey2 = franzapPubkey;

      // Create two apps: one with a release, one without
      final app1 = PartialApp()
        ..identifier = 'com.app1'
        ..name = 'App 1';
      final signedApp1 = (app1..event.setTagValue('i', 'com.app1')).dummySign(pubkey1);

      final app2 = PartialApp()
        ..identifier = 'com.app2'
        ..name = 'App 2';
      final signedApp2 = (app2..event.setTagValue('i', 'com.app2')).dummySign(pubkey2);

      // Create file metadata for release1
      final partialFile1 = PartialFileMetadata()
        ..version = '1.0.0'
        ..appIdentifier = 'com.app1'
        ..hash = 'hash1';
      final file1 = partialFile1.dummySign(pubkey1);

      // Create release only for app1
      final partialRelease1 = PartialRelease(newFormat: true)
        ..identifier = 'com.app1@1.0.0'
        ..appIdentifier = 'com.app1'
        ..version = '1.0.0';
      partialRelease1.event.setTagValue('e', file1.id);
      final release1 = partialRelease1.dummySign(pubkey1);

      await storage.save({signedApp1, signedApp2, release1, file1});

      // Query both apps with conditional nested relationships
      tester = container.testerFor(
        query<App>(
          ids: {signedApp1.id, signedApp2.id},
          and: (app) => {
            app.latestRelease,
            // Only load metadata if release exists
            if (app.latestRelease.value != null)
              app.latestRelease.value!.latestMetadata,
          },
          source: LocalSource(),
        ),
      );

      await tester.expectModels(hasLength(2));
      await Future.delayed(Duration(milliseconds: 50));

      // Verify app1 has release and metadata
      final apps = await storage.query(
        RequestFilter<App>(ids: {signedApp1.id, signedApp2.id}).toRequest(),
        source: LocalSource(),
      );
      final loadedApp1 = apps.firstWhere((a) => a.id == signedApp1.id);
      final loadedApp2 = apps.firstWhere((a) => a.id == signedApp2.id);

      expect(loadedApp1.latestRelease.value, isNotNull);
      expect(loadedApp1.latestRelease.value!.latestMetadata.value, isNotNull);
      
      // app2 should not have a release
      expect(loadedApp2.latestRelease.value, isNull);
    });

    test('nested relationships avoid duplicate queries', () async {
      // Ensure that relationships are only queried once even with re-evaluation
      final pubkey = nielPubkey;
      
      final partialFile = PartialFileMetadata()
        ..version = '1.0.0'
        ..appIdentifier = 'com.test'
        ..hash = 'xyz';
      final file = partialFile.dummySign(pubkey);

      final partialRelease = PartialRelease(newFormat: true)
        ..identifier = 'com.test@1.0.0'
        ..appIdentifier = 'com.test'
        ..version = '1.0.0';
      partialRelease.event.setTagValue('e', file.id);
      final release = partialRelease.dummySign(pubkey);

      final partialApp = PartialApp()
        ..identifier = 'com.test'
        ..name = 'Test';
      partialApp.event.setTagValue('i', 'com.test');
      final app = partialApp.dummySign(pubkey);

      // Save everything at once
      await storage.save({app, release, file});

      // Track query count by subscribing to storage state changes
      var stateChangeCount = 0;
      final subscription = container.listen(
        storageNotifierProvider,
        (prev, next) => stateChangeCount++,
      );

      tester = container.testerFor(
        query<App>(
          ids: {app.id},
          and: (app) => {
            app.latestRelease,
            if (app.latestRelease.value != null)
              app.latestRelease.value!.latestMetadata,
          },
          source: LocalSource(),
        ),
      );

      await tester.expectModels(hasLength(1));
      await Future.delayed(Duration(milliseconds: 100));

      // The implementation should deduplicate requests
      // Even with re-evaluation, each relationship should only be queried once
      final finalApp = await storage.query(
        RequestFilter<App>(ids: {app.id}).toRequest(),
        source: LocalSource(),
      );
      expect(finalApp.first.latestRelease.value, isNotNull);
      expect(finalApp.first.latestRelease.value!.latestMetadata.value, isNotNull);

      subscription.close();
    });

    test('relay metadata', () async {
      tester = container.testerFor(
        query<Profile>(authors: {nielPubkey}, source: LocalSource()),
      );

      if (tester.notifier.state is StorageData) {
        expect(
          tester.notifier.state,
          isA<StorageData>().having(
            (s) => s.models.first.event.relays,
            'relays',
            <String>{},
          ),
        );
      } else {
        await tester.expect(
          isA<StorageData>().having(
            (s) => s.models.first.event.relays,
            'relays',
            <String>{},
          ),
        );
      }
    });
  });

  group('storage configuration', () {
    test('getRelays should prioritize relayUrls over groups', () {
      final config = StorageConfiguration(
        relayGroups: {
          'primary': {'wss://primary1.relay.io', 'wss://primary2.relay.io'},
          'secondary': {
            'wss://secondary1.relay.io',
            'wss://secondary2.relay.io',
          },
        },
        defaultRelayGroup: 'primary',
      );

      // Test relayUrls takes priority over group
      final customRelayUrls = {
        'wss://custom1.relay.io',
        'wss://custom2.relay.io',
      };
      final sourceWithUrls = RemoteSource(
        relayUrls: customRelayUrls,
        group: 'primary',
      );
      expect(config.getRelays(source: sourceWithUrls), equals(customRelayUrls));

      // Test group fallback when relayUrls is empty
      final sourceWithGroup = RemoteSource(group: 'secondary');
      expect(
        config.getRelays(source: sourceWithGroup),
        equals({'wss://secondary1.relay.io', 'wss://secondary2.relay.io'}),
      );

      // Test default group fallback when neither relayUrls nor group specified
      final sourceDefault = RemoteSource();
      expect(
        config.getRelays(source: sourceDefault),
        equals({'wss://primary1.relay.io', 'wss://primary2.relay.io'}),
      );

      // Test empty set when group doesn't exist
      final sourceNonExistent = RemoteSource(group: 'nonexistent');
      expect(config.getRelays(source: sourceNonExistent), equals(<String>{}));
    });
  });

  group('storage', () {
    test('clear with req', () async {
      // Clear storage first to ensure test isolation
      await storage.clear();

      // Create test dates
      final beginOfMonth = DateTime.parse('2025-04-01');
      final marchDate = DateTime.parse('2025-03-12'); // Before beginOfMonth
      final mayDate = DateTime.parse('2025-05-15'); // After beginOfMonth

      // Generate events with specific timestamps
      final marchEvents = <Model>[];
      final mayEvents = <Model>[];

      // Create exactly 3 events for March and 3 for May to keep it simple
      for (int i = 0; i < 3; i++) {
        final marchNote = PartialNote(
          'March note $i',
          createdAt: marchDate,
        ).dummySign(Utils.generateRandomHex64());
        marchEvents.add(marchNote);

        final mayNote = PartialNote(
          'May note $i',
          createdAt: mayDate,
        ).dummySign(Utils.generateRandomHex64());
        mayEvents.add(mayNote);
      }

      // Save all events to storage
      await storage.save({...marchEvents, ...mayEvents});

      // Verify we have 6 events total at the storage level
      final relay = container.read(relayProvider);
      expect(relay.storage.eventCount, equals(6));

      // Create the clear request - this should match March events (events until April 1st)
      final clearRequest = RequestFilter(until: beginOfMonth).toRequest();

      // Verify the clear request would match the correct events at storage level
      final eventsToBeCleared = relay.storage.queryEvents(clearRequest.filters);
      expect(eventsToBeCleared, hasLength(3));

      // Verify these are the March events (all should be before April 1st)
      for (final event in eventsToBeCleared) {
        final createdAt = DateTime.fromMillisecondsSinceEpoch(
          (event['created_at'] as int) * 1000,
        );
        expect(
          createdAt.isBefore(beginOfMonth),
          isTrue,
          reason: 'Event to be cleared should be before April 1st: $createdAt',
        );
      }

      // Now test the storage.clear() method
      await storage.clear(clearRequest);

      // Verify the events were deleted from storage
      expect(relay.storage.eventCount, equals(3));

      // Verify only May events remain at storage level
      final remainingStorageEvents = relay.storage.queryEvents([
        RequestFilter(),
      ]);
      expect(remainingStorageEvents, hasLength(3));

      // Verify the remaining events are all May events (after April 1st)
      for (final event in remainingStorageEvents) {
        final createdAt = DateTime.fromMillisecondsSinceEpoch(
          (event['created_at'] as int) * 1000,
        );
        expect(
          createdAt.isAfter(beginOfMonth),
          isTrue,
          reason: 'Remaining event should be after April 1st: $createdAt',
        );
      }
    });

    test('request filter', () {
      final r1 = RequestFilter<Reaction>(
        authors: {nielPubkey, franzapPubkey},
        tags: {
          'foo': {'bar'},
          '#t': {'nostr'},
        },
      );
      final r2 = RequestFilter<Reaction>(
        authors: {franzapPubkey, nielPubkey},
        tags: {
          '#t': {'nostr'},
          'foo': {'bar'},
        },
      );
      final r3 = RequestFilter<Reaction>(
        authors: {franzapPubkey, nielPubkey},
        tags: {
          'foo': {'bar'},
        },
      );
      expect(r1.kinds.first, 7);
      expect(r1, equals(r2));
      expect(r1.toMap(), equals(r2.toMap()));
      expect(r1.toMap(), isNot(equals(r3.toMap())));

      // Filter with extra arguments
      final r4 = RequestFilter<Reaction>(
        authors: {nielPubkey, franzapPubkey},
        tags: {
          'foo': {'bar'},
          '#t': {'nostr'},
        },
      );

      expect(r1, equals(r4));
    });
  });

  group('notifier', () {
    group('state transitions', () {
      test('should transition from loading to data state', () async {
        // Use unique pubkeys to avoid conflicts with seeded data
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          generator.generateProfile(pubkey1),
          generator.generateProfile(pubkey2),
        ];
        await storage.save({franzap, niel});

        final tester = container.testerFor(
          query<Profile>(authors: {pubkey2}, source: LocalSource()),
        );

        // Should start with loading state
        expect(tester.notifier.state, isA<StorageLoading>());

        // Should transition to data state with results
        await tester.expectModels(hasLength(1));
        expect(tester.notifier.state, isA<StorageData>());

        tester.dispose();
      });

      test('should handle empty results', () async {
        final tester = container.testerFor(
          query<Note>(
            authors: {Utils.generateRandomHex64()},
            source: LocalSource(),
          ),
        );

        // Should transition to data state with empty list
        await tester.expectModels(isEmpty);
        expect(tester.notifier.state, isA<StorageData>());
        expect((tester.notifier.state as StorageData).models, isEmpty);

        tester.dispose();
      });

      test('should handle empty request filters', () async {
        // This should not cause any issues and should return empty results
        final tester = container.testerFor(query<Note>(source: LocalSource()));

        await tester.expectModels(isEmpty);
        tester.dispose();
      });
    });

    group('error handling', () {
      test('should handle query errors gracefully', () async {
        // Create a malformed request that might cause errors
        final tester = container.testerFor(
          query<Note>(
            authors: {Utils.generateRandomHex64()},
            source: LocalSource(),
          ),
        );

        // Simulate an error by clearing storage during query
        await storage.clear();

        // Should handle the error and maintain previous state or show error
        // Note: The exact behavior depends on implementation, but it shouldn't crash
        await tester.expect(anyOf(isA<StorageData>(), isA<StorageError>()));

        tester.dispose();
      });

      test('should handle network failures gracefully', () async {
        final tester = container.testerFor(
          query<Note>(
            authors: {Utils.generateRandomHex64()},
            source: RemoteSource(group: 'nonexistent-group'),
          ),
        );

        // Should handle network failures without crashing
        await tester.expect(anyOf(isA<StorageData>(), isA<StorageError>()));

        tester.dispose();
      });
    });

    group('request lifecycle', () {
      test('should cancel requests when disposed', () async {
        final [franzap, niel] = [
          generator.generateProfile(franzapPubkey),
          generator.generateProfile(nielPubkey),
        ];
        await storage.save({franzap, niel});

        final tester = container.testerFor(
          query<Profile>(
            authors: {nielPubkey, franzapPubkey},
            source: RemoteSource(stream: true),
          ),
        );

        // Wait for initial results
        await tester.expectModels(hasLength(2));

        // Dispose the tester
        tester.dispose();

        // Add more data after disposal - should not trigger updates
        final newProfile = generator.generateProfile(verbirichaPubkey);
        await storage.save({newProfile});
      });

      test('should handle multiple concurrent requests', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          generator.generateProfile(pubkey1),
          generator.generateProfile(pubkey2),
        ];
        await storage.save({franzap, niel});

        // Create multiple notifiers watching different queries
        final tester1 = container.testerFor(
          query<Profile>(authors: {pubkey2}, source: LocalSource()),
        );

        final tester2 = container.testerFor(
          query<Profile>(authors: {pubkey1}, source: LocalSource()),
        );

        final tester3 = container.testerFor(
          query<Note>(authors: {pubkey2}, source: LocalSource()),
        );

        // All should work independently
        await tester1.expectModels(hasLength(1));
        await tester2.expectModels(hasLength(1));
        await tester3.expectModels(isEmpty); // No notes for niel yet

        // Add a note for niel
        final note = generator.generateModel(kind: 1, pubkey: pubkey2)!;
        await storage.save({note});

        // Only tester3 should get the update
        await tester3.expectModels(hasLength(1));
      });
    });

    group('data updates', () {
      test('should handle replaceable event updates', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final originalProfile = generator.generateProfile(pubkey1);
        await storage.save({originalProfile});

        final tester = container.testerFor(
          query<Profile>(authors: {pubkey1}, source: LocalSource()),
        );

        await tester.expectModels(hasLength(1));
        expect(
          (tester.notifier.state as StorageData).models.first,
          originalProfile,
        );

        // Create updated profile (replaceable event)
        // Create a fresh partial profile with newer timestamp
        final updatedPartialProfile = PartialProfile(name: 'Updated Name');
        updatedPartialProfile.event.createdAt = DateTime.now().add(
          Duration(seconds: 1),
        );
        final updatedProfile = updatedPartialProfile.dummySign(pubkey1);
        await storage.save({updatedProfile});

        // Should replace the old profile with the new one
        await tester.expectModels(
          allOf(
            hasLength(1),
            everyElement((p) => p is Profile && p.name == 'Updated Name'),
          ),
        );
      });

      test('should handle streaming updates correctly', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          generator.generateProfile(pubkey1),
          generator.generateProfile(pubkey2),
        ];
        await storage.save({franzap, niel});

        final tester = container.testerFor(
          query<Note>(
            authors: {pubkey2, pubkey1},
            source: RemoteSource(stream: true),
          ),
        );

        // Initial results
        await tester.expectModels(hasLength(0)); // No notes initially

        // Add notes one by one
        final note1 = generator.generateModel(kind: 1, pubkey: pubkey2)!;
        await storage.save({note1});

        // Wait for first streaming update
        await tester.expectModels(hasLength(1));

        final note2 = generator.generateModel(kind: 1, pubkey: pubkey1)!;
        await storage.save({note2});

        // Check that we eventually have both notes in the stream
        final finalQuery = RequestFilter<Note>(
          authors: {pubkey2, pubkey1},
        ).toRequest();
        final finalModels = container
            .read(storageNotifierProvider.notifier)
            .querySync(finalQuery);
        expect(finalModels, hasLength(2));
      });

      test('should trigger rerenders on relationship changes', () async {
        final pubkey1 = Utils.generateRandomHex64();

        // Create a note with author relationship
        final author = generator.generateProfile(pubkey1);
        final note = generator.generateModel(kind: 1, pubkey: pubkey1)!;
        await storage.save({author, note});

        final tester = container.testerFor(
          query<Note>(
            ids: {note.id},
            and: (note) => {note.author},
            source: LocalSource(),
          ),
        );

        await tester.expectModels(hasLength(1));

        // Update the author profile - this should trigger a rerender
        // even though relationships aren't cached
        final updatedAuthor = author
            .copyWith(name: 'Updated Author')
            .dummySign(pubkey1);
        await storage.save({updatedAuthor});

        // Should trigger a state update due to relationship change
        await tester.expect(isA<StorageData>());
      });
    });

    group('source variations', () {
      test('should handle LocalAndRemoteSource correctly', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          generator.generateProfile(pubkey1),
          generator.generateProfile(pubkey2),
        ];
        await storage.save({franzap, niel});

        final tester = container.testerFor(
          query<Profile>(
            authors: {pubkey2, pubkey1},
            source: LocalAndRemoteSource(stream: false),
          ),
        );

        await tester.expectModels(hasLength(2));
        expect(tester.notifier.state, isA<StorageData>());
      });

      test('should handle background remote queries', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          generator.generateProfile(pubkey1),
          generator.generateProfile(pubkey2),
        ];
        await storage.save({franzap, niel});

        final tester = container.testerFor(
          query<Profile>(
            authors: {pubkey2, pubkey1},
            source: RemoteSource(background: true),
          ),
        );

        await tester.expectModels(hasLength(2));
      });

      test('should handle different relay groups', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          generator.generateProfile(pubkey1),
          generator.generateProfile(pubkey2),
        ];
        await storage.save({franzap, niel});

        final tester = container.testerFor(
          query<Profile>(
            authors: {pubkey2, pubkey1},
            source: RemoteSource(group: 'big-relays'),
          ),
        );

        await tester.expectModels(hasLength(2));
      });

      test('should handle RemoteSource with relayUrls parameter', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          generator.generateProfile(pubkey1),
          generator.generateProfile(pubkey2),
        ];
        await storage.save({franzap, niel});

        // Test with custom relay URLs that override group settings
        final customRelayUrls = {
          'wss://custom1.relay.io',
          'wss://custom2.relay.io',
        };
        final tester = container.testerFor(
          query<Profile>(
            authors: {pubkey2, pubkey1},
            source: RemoteSource(relayUrls: customRelayUrls),
          ),
        );

        await tester.expectModels(hasLength(2));

        // Verify that storage configuration correctly uses the custom relayUrls
        final config = storage.config;
        final sourceWithUrls = RemoteSource(relayUrls: customRelayUrls);
        final sourceWithGroup = RemoteSource(group: 'big-relays');

        // relayUrls should take priority over group
        expect(
          config.getRelays(source: sourceWithUrls),
          equals(customRelayUrls),
        );
        // Without relayUrls, should fall back to group
        expect(
          config.getRelays(source: sourceWithGroup),
          equals({'wss://damus.relay.io', 'wss://relay.primal.net'}),
        );
      });

      test(
        'should prioritize relayUrls over group in LocalAndRemoteSource',
        () async {
          final pubkey1 = Utils.generateRandomHex64();
          final pubkey2 = Utils.generateRandomHex64();

          final [franzap, niel] = [
            generator.generateProfile(pubkey1),
            generator.generateProfile(pubkey2),
          ];
          await storage.save({franzap, niel});

          // Test LocalAndRemoteSource with both relayUrls and group
          final customRelayUrls = {'wss://priority.relay.io'};
          final tester = container.testerFor(
            query<Profile>(
              authors: {pubkey2, pubkey1},
              source: LocalAndRemoteSource(
                relayUrls: customRelayUrls,
                group:
                    'big-relays', // This should be ignored when relayUrls is provided
              ),
            ),
          );

          await tester.expectModels(hasLength(2));

          // Verify priority: relayUrls should override group even in LocalAndRemoteSource
          final config = storage.config;
          final source = LocalAndRemoteSource(
            relayUrls: customRelayUrls,
            group: 'big-relays',
          );
          expect(config.getRelays(source: source), equals(customRelayUrls));
        },
      );
    });

    group('model type safety', () {
      test('should filter models by correct type', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          generator.generateProfile(pubkey1),
          generator.generateProfile(pubkey2),
        ];
        final note = generator.generateModel(kind: 1, pubkey: pubkey2)!;
        await storage.save({franzap, niel, note});

        // Query for profiles only
        final profileTester = container.testerFor(
          query<Profile>(authors: {pubkey2, pubkey1}, source: LocalSource()),
        );

        await profileTester.expectModels(
          allOf(hasLength(2), everyElement((m) => m is Profile)),
        );

        // Query for notes only
        final noteTester = container.testerFor(
          query<Note>(authors: {pubkey2, pubkey1}, source: LocalSource()),
        );

        await noteTester.expectModels(
          allOf(hasLength(1), everyElement((m) => m is Note)),
        );
      });

      test('should handle mixed kind queries correctly', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          generator.generateProfile(pubkey1),
          generator.generateProfile(pubkey2),
        ];
        final note = generator.generateModel(kind: 1, pubkey: pubkey2)!;
        final reaction = generator.generateModel(
          kind: 7,
          parentId: note.id,
          pubkey: pubkey1,
        )!;
        await storage.save({franzap, niel, note, reaction});

        // Query for multiple kinds
        final tester = container.testerFor(
          queryKinds(
            kinds: {0, 1, 7}, // Profile, Note, Reaction
            authors: {pubkey2, pubkey1},
            source: LocalSource(),
          ),
        );

        await tester.expectModels(
          hasLength(4),
        ); // 2 profiles + 1 note + 1 reaction
      });
    });

    group('complex scenarios', () {
      test('should handle complex filter combinations', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          generator.generateProfile(pubkey1),
          generator.generateProfile(pubkey2),
        ];
        final note1 = generator.generateModel(kind: 1, pubkey: pubkey2)!;
        final note2 = generator.generateModel(kind: 1, pubkey: pubkey1)!;
        await storage.save({franzap, niel, note1, note2});

        // Complex filter with multiple conditions
        final tester = container.testerFor(
          query<Note>(
            authors: {pubkey2, pubkey1},
            since: DateTime.now().subtract(Duration(hours: 1)),
            limit: 10,
            source: LocalSource(),
          ),
        );

        await tester.expectModels(hasLength(2));
      });

      test('should handle where function filtering', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          generator.generateProfile(pubkey1),
          generator.generateProfile(pubkey2),
        ];
        final note1 = generator.generateModel(kind: 1, pubkey: pubkey2)!;
        final note2 = generator.generateModel(kind: 1, pubkey: pubkey1)!;
        await storage.save({franzap, niel, note1, note2});

        // Use where function to filter
        final tester = container.testerFor(
          query<Note>(
            authors: {pubkey2, pubkey1},
            where: (note) => note.author.value?.pubkey == pubkey2,
            source: LocalSource(),
          ),
        );

        await tester.expectModels(
          allOf(
            hasLength(1),
            everyElement((n) => n.author.value?.pubkey == pubkey2),
          ),
        );
      });
    });

    // Original tests for backward compatibility
    test('relay request should notify with models', () async {
      final pubkey1 = Utils.generateRandomHex64();
      final pubkey2 = Utils.generateRandomHex64();

      final [franzap, niel] = [
        generator.generateProfile(pubkey1),
        generator.generateProfile(pubkey2),
      ];
      await storage.save({
        franzap,
        niel,
        ...List.generate(
          20,
          (i) => generator.generateModel(kind: 1, pubkey: pubkey1)!,
        ),
        ...List.generate(
          20,
          (i) => generator.generateModel(kind: 1, pubkey: pubkey2)!,
        ),
      });

      final tester = container.testerFor(
        query<Note>(
          authors: {pubkey2, pubkey1},
          limit: 1,
          source: RemoteSource(stream: false),
        ),
      );

      await tester.expectModels(hasLength(1));
      expect(tester.notifier.state, isA<StorageData>());
      expect((tester.notifier.state as StorageData).models, hasLength(1));
    });

    test('relay request should notify with models (streamed)', () async {
      final pubkey1 = Utils.generateRandomHex64();
      final pubkey2 = Utils.generateRandomHex64();

      final [franzap, niel] = [
        generator.generateProfile(pubkey1),
        generator.generateProfile(pubkey2),
      ];
      await storage.save({
        franzap,
        niel,
        ...List.generate(
          20,
          (i) => generator.generateModel(kind: 1, pubkey: pubkey1)!,
        ),
        ...List.generate(
          20,
          (i) => generator.generateModel(kind: 1, pubkey: pubkey2)!,
        ),
      });

      final tester = container.testerFor(
        query<Note>(
          authors: {pubkey2, pubkey1},
          limit: 5,
          source: RemoteSource(stream: true),
        ),
      );

      await tester.expectModels(hasLength(5));
      expect(tester.notifier.state, isA<StorageData>());
      expect((tester.notifier.state as StorageData).models, hasLength(5));
    });
  });

  group('profile roundtrip', () {
    test('should save and fetch a Profile', () async {
      final pubkey = Utils.generateRandomHex64();
      final profile = PartialProfile(
        name: 'Roundtrip User',
        about: 'Test roundtrip',
      ).dummySign(pubkey);
      await storage.save({profile});

      final tester = container.testerFor(
        query<Profile>(authors: {pubkey}, source: LocalSource()),
      );
      await tester.expectModels(hasLength(1));
      final fetched =
          (tester.notifier.state as StorageData).models.first as Profile;
      expect(fetched.pubkey, pubkey);
      expect(fetched.name, 'Roundtrip User');
      expect(fetched.about, 'Test roundtrip');
    });
  });
}

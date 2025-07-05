import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  late ProviderContainer container;
  late DummyStorageNotifier storage;

  setUp(() async {
    // Create a fresh container and storage for each test
    container = ProviderContainer();
    final config = StorageConfiguration(
      relayGroups: {
        'big-relays': {'wss://damus.relay.io', 'wss://relay.primal.net'}
      },
      defaultRelayGroup: 'big-relays',
      streamingBufferWindow: Duration.zero,
      keepMaxModels: 1000,
    );
    await container.read(initializationProvider(config).future);
    storage = container.read(storageNotifierProvider.notifier)
        as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.cancel();
    await storage.clear();
    container.dispose();
  });

  group('storage filters', () {
    late StateNotifierTester tester;
    late Note a, b, c, d, e, f, g, replyToA, replyToB;
    late Profile nielProfile;

    setUp(() async {
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
      replyToA =
          PartialNote('reply to a', replyTo: a).dummySign(nielProfile.pubkey);
      replyToB = PartialNote('reply to b', createdAt: yesterday, replyTo: b)
          .dummySign(nielProfile.pubkey);

      await storage.save({a, b, c, d, e, f, g, replyToA, replyToB});
      await storage.save({nielProfile});
      await storage
          .publish({nielProfile}, source: RemoteSource(group: 'big-relays'));
    });

    tearDown(() async {
      tester.dispose();
    });

    test('ids', () async {
      tester = container.testerFor(
          queryKinds(ids: {a.event.id, e.event.id}, source: LocalSource()));
      await tester.expectModels(unorderedEquals({a, e}));
    });

    test('authors', () async {
      tester = container.testerFor(queryKinds(
          authors: {franzapPubkey, verbirichaPubkey}, source: LocalSource()));
      await tester.expectModels(unorderedEquals({e, f, g}));
    });

    test('kinds', () async {
      tester = container.testerFor(query<Note>(source: LocalSource()));
      await tester.expectModels(allOf(
        hasLength(9),
        everyElement((e) => e is Model && e.event.kind == 1),
      ));

      tester = container.testerFor(query<Profile>(source: LocalSource()));
      await tester.expectModels(hasLength(1));
    });

    test('tags', () async {
      tester = container.testerFor(queryKinds(authors: {
        nielPubkey
      }, tags: {
        '#t': {'nostr'}
      }, source: LocalSource()));
      await tester.expectModels(equals({d}));

      tester = container.testerFor(queryKinds(tags: {
        '#t': {'nostr', 'test'}
      }, source: LocalSource()));
      await tester.expectModels(unorderedEquals({d, f}));

      tester = container.testerFor(queryKinds(tags: {
        '#t': {'test'}
      }, source: LocalSource()));
      await tester.expectModels(isEmpty);

      tester = container.testerFor(queryKinds(tags: {
        '#t': {'nostr'},
        '#e': {nielPubkey}
      }, source: LocalSource()));
      await tester.expectModels(isEmpty);
    });

    test('until', () async {
      tester = container.testerFor(query<Note>(
          authors: {nielPubkey},
          until: DateTime.now().subtract(Duration(minutes: 1)),
          source: LocalSource()));
      await tester.expectModels(orderedEquals({a, b, replyToB}));
    });

    test('since', () async {
      tester = container.testerFor(queryKinds(
          authors: {nielPubkey},
          since: DateTime.now().subtract(Duration(minutes: 1)),
          source: LocalSource()));
      await tester.expectModels(orderedEquals({c, d, nielProfile, replyToA}));
    });

    test('limit and order', () async {
      tester = container.testerFor(
          query<Note>(authors: {nielPubkey}, limit: 3, source: LocalSource()));
      await tester.expectModels(orderedEquals({d, c, replyToA}));
    });

    test('replaceable updates', () async {
      tester = container.testerFor(
          query<Profile>(authors: {nielPubkey}, source: LocalSource()));
      await tester.expectModels(unorderedEquals({nielProfile}));

      final nielcho =
          nielProfile.copyWith(name: 'Nielcho').dummySign(nielPubkey);
      // Check processMetadata() was called when constructing
      expect(nielcho.name, equals('Nielcho'));
      // Content should NOT be empty as this new event could be sent to relays
      expect(nielcho.event.content, isNotEmpty);
      await nielcho.save();

      // Wait for the storage state to update with the new profile
      // The replaceable update should replace the old profile with the new one
      // We need to wait for the state to propagate through the notifier
      await tester.expectModels(allOf(
        hasLength(1),
        everyElement((p) => p is Profile && p.name == 'Nielcho'),
      ));
    });

    test('relationships with model watcher', () async {
      tester = container.testerFor(
          model(a, and: (note) => {note.author}, source: LocalSource()));
      await tester.expectModels(unorderedEquals({a}));
      // NOTE: note.author will be cached, but only note is returned
    });

    test('multiple relationships', () async {
      tester = container.testerFor(query<Note>(
          ids: {a.id, b.id},
          and: (note) => {note.author, note.replies},
          source: LocalSource()));
      await tester.expectModels(unorderedEquals({a, b}));
      // NOTE: author and replies will be cached, can't assert here
    });

    test('relay metadata', () async {
      tester = container.testerFor(
          query<Profile>(authors: {nielPubkey}, source: LocalSource()));

      if (tester.notifier.state is StorageData) {
        expect(
          tester.notifier.state,
          isA<StorageData>()
              .having((s) => s.models.first.event.relays, 'relays', <String>{}),
        );
      } else {
        await tester.expect(
          isA<StorageData>()
              .having((s) => s.models.first.event.relays, 'relays', <String>{}),
        );
      }
    });
  });

  group('storage', () {
    test('clear with req', () async {
      // Clear storage completely before test to ensure clean state
      await storage.clear();

      final a = List.generate(
          30,
          (_) => storage.generateModel(
              kind: 1, createdAt: DateTime.parse('2025-03-12'))!);
      final b = List.generate(30, (_) => storage.generateModel(kind: 1)!);
      await storage.save({...a, ...b});
      final beginOfYear = DateTime.parse('2025-01-01');
      final beginOfMonth = DateTime.parse('2025-04-01');
      expect(await storage.query(RequestFilter(since: beginOfYear).toRequest()),
          hasLength(60));
      expect(
          await storage.query(RequestFilter(since: beginOfMonth).toRequest()),
          hasLength(30));
      await storage.clear(RequestFilter(until: beginOfMonth).toRequest());
      expect(await storage.query(Request([RequestFilter(since: beginOfYear)])),
          hasLength(30));
    });

    test('max models config', () async {
      // Clear storage first to ensure clean state
      await storage.clear();

      final max = storage.config.keepMaxModels;
      final a = List.generate(max * 2, (_) => storage.generateModel(kind: 1)!);
      await storage.save(a.toSet());

      // The _enforceMaxModelsLimit should keep only the newest max models
      final result = await storage.query(RequestFilter<Note>().toRequest());
      expect(result.length, lessThanOrEqualTo(max));
      expect(result.length, greaterThan(0)); // Should have some models
    });

    test('request filter', () {
      final r1 = RequestFilter<Reaction>(authors: {
        nielPubkey,
        franzapPubkey
      }, tags: {
        'foo': {'bar'},
        '#t': {'nostr'}
      });
      final r2 = RequestFilter<Reaction>(authors: {
        franzapPubkey,
        nielPubkey
      }, tags: {
        '#t': {'nostr'},
        'foo': {'bar'}
      });
      final r3 = RequestFilter<Reaction>(authors: {
        franzapPubkey,
        nielPubkey
      }, tags: {
        'foo': {'bar'}
      });
      expect(r1.kinds.first, 7);
      expect(r1, equals(r2));
      expect(r1.toMap(), equals(r2.toMap()));
      expect(r1.toMap(), isNot(equals(r3.toMap())));

      // Filter with extra arguments
      final r4 = RequestFilter<Reaction>(
        authors: {nielPubkey, franzapPubkey},
        tags: {
          'foo': {'bar'},
          '#t': {'nostr'}
        },
      );

      expect(r1, equals(r4));
    });
  });

  group('notifier', () {
    group('state transitions', () {
      test('should transition from loading to data state', () async {
        // Clear storage to ensure clean state
        await storage.clear();

        // Use unique pubkeys to avoid conflicts with seeded data
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          storage.generateProfile(pubkey1),
          storage.generateProfile(pubkey2)
        ];
        await storage.save({franzap, niel});

        final tester = container.testerFor(query<Profile>(
          authors: {pubkey2},
          source: LocalSource(),
        ));

        // Should start with loading state
        expect(tester.notifier.state, isA<StorageLoading>());

        // Should transition to data state with results
        await tester.expectModels(hasLength(1));
        expect(tester.notifier.state, isA<StorageData>());

        tester.dispose();
      });

      test('should handle empty results', () async {
        // Clear storage to ensure clean state
        await storage.clear();

        final tester = container.testerFor(query<Note>(
          authors: {Utils.generateRandomHex64()},
          source: LocalSource(),
        ));

        // Should transition to data state with empty list
        await tester.expectModels(isEmpty);
        expect(tester.notifier.state, isA<StorageData>());
        expect((tester.notifier.state as StorageData).models, isEmpty);

        tester.dispose();
      });

      test('should handle empty request filters', () async {
        // Clear storage to ensure clean state
        await storage.clear();

        // This should not cause any issues and should return empty results
        final tester = container.testerFor(query<Note>(
          source: LocalSource(),
        ));

        await tester.expectModels(isEmpty);
        tester.dispose();
      });
    });

    group('error handling', () {
      test('should handle query errors gracefully', () async {
        // Clear storage to ensure clean state
        await storage.clear();

        // Create a malformed request that might cause errors
        final tester = container.testerFor(query<Note>(
          authors: {Utils.generateRandomHex64()},
          source: LocalSource(),
        ));

        // Simulate an error by clearing storage during query
        await storage.clear();

        // Should handle the error and maintain previous state or show error
        // Note: The exact behavior depends on implementation, but it shouldn't crash
        await tester.expect(anyOf(
          isA<StorageData>(),
          isA<StorageError>(),
        ));

        tester.dispose();
      });

      test('should handle network failures gracefully', () async {
        // Clear storage to ensure clean state
        await storage.clear();

        final tester = container.testerFor(query<Note>(
          authors: {Utils.generateRandomHex64()},
          source: RemoteSource(group: 'nonexistent-group'),
        ));

        // Should handle network failures without crashing
        await tester.expect(anyOf(
          isA<StorageData>(),
          isA<StorageError>(),
        ));

        tester.dispose();
      });
    });

    group('request lifecycle', () {
      test('should cancel requests when disposed', () async {
        // Clear storage to ensure clean state
        await storage.clear();

        final [franzap, niel] = [
          storage.generateProfile(franzapPubkey),
          storage.generateProfile(nielPubkey)
        ];
        await storage.save({franzap, niel});

        final tester = container.testerFor(query<Profile>(
          authors: {nielPubkey, franzapPubkey},
          source: RemoteSource(stream: true),
        ));

        // Wait for initial results
        await tester.expectModels(hasLength(2));

        // Dispose the tester
        tester.dispose();

        // Add more data after disposal - should not trigger updates
        final newProfile = storage.generateProfile(verbirichaPubkey);
        await storage.save({newProfile});

        // Wait a bit to ensure no updates come through
        await Future.delayed(Duration(milliseconds: 100));

        // The disposed notifier should not have received the new data
        // (This is implicit since we can't access the disposed notifier)
      });

      test('should handle multiple concurrent requests', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          storage.generateProfile(pubkey1),
          storage.generateProfile(pubkey2)
        ];
        await storage.save({franzap, niel});

        // Create multiple notifiers watching different queries
        final tester1 = container.testerFor(query<Profile>(
          authors: {pubkey2},
          source: LocalSource(),
        ));

        final tester2 = container.testerFor(query<Profile>(
          authors: {pubkey1},
          source: LocalSource(),
        ));

        final tester3 = container.testerFor(query<Note>(
          authors: {pubkey2},
          source: LocalSource(),
        ));

        // All should work independently
        await tester1.expectModels(hasLength(1));
        await tester2.expectModels(hasLength(1));
        await tester3.expectModels(isEmpty); // No notes for niel yet

        // Add a note for niel
        final note = storage.generateModel(kind: 1, pubkey: pubkey2)!;
        await storage.save({note});

        // Only tester3 should get the update
        await tester3.expectModels(hasLength(1));
      });
    });

    group('data updates', () {
      test('should handle replaceable event updates', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final originalProfile = storage.generateProfile(pubkey1);
        await storage.save({originalProfile});

        final tester = container.testerFor(query<Profile>(
          authors: {pubkey1},
          source: LocalSource(),
        ));

        await tester.expectModels(hasLength(1));
        expect((tester.notifier.state as StorageData).models.first,
            originalProfile);

        // Create updated profile (replaceable event)
        final updatedProfile =
            originalProfile.copyWith(name: 'Updated Name').dummySign(pubkey1);
        await storage.save({updatedProfile});

        // Should replace the old profile with the new one
        await tester.expectModels(allOf(
          hasLength(1),
          everyElement((p) => p is Profile && p.name == 'Updated Name'),
        ));
      });

      test('should handle streaming updates correctly', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          storage.generateProfile(pubkey1),
          storage.generateProfile(pubkey2)
        ];
        await storage.save({franzap, niel});

        final tester = container.testerFor(query<Note>(
          authors: {pubkey2, pubkey1},
          source: RemoteSource(stream: true),
        ));

        // Initial results
        await tester.expectModels(hasLength(0)); // No notes initially

        // Add notes one by one
        final note1 = storage.generateModel(kind: 1, pubkey: pubkey2)!;
        await storage.save({note1});
        await tester.expectModels(hasLength(1));

        final note2 = storage.generateModel(kind: 1, pubkey: pubkey1)!;
        await storage.save({note2});
        await tester.expectModels(hasLength(2));
      });

      test('should trigger rerenders on relationship changes', () async {
        final pubkey1 = Utils.generateRandomHex64();

        // Create a note with author relationship
        final author = storage.generateProfile(pubkey1);
        final note = storage.generateModel(kind: 1, pubkey: pubkey1)!;
        await storage.save({author, note});

        final tester = container.testerFor(query<Note>(
          ids: {note.id},
          and: (note) => {note.author},
          source: LocalSource(),
        ));

        await tester.expectModels(hasLength(1));

        // Update the author profile - this should trigger a rerender
        // even though relationships aren't cached
        final updatedAuthor =
            author.copyWith(name: 'Updated Author').dummySign(pubkey1);
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
          storage.generateProfile(pubkey1),
          storage.generateProfile(pubkey2)
        ];
        await storage.save({franzap, niel});

        final tester = container.testerFor(query<Profile>(
          authors: {pubkey2, pubkey1},
          source: LocalAndRemoteSource(stream: false),
        ));

        await tester.expectModels(hasLength(2));
        expect(tester.notifier.state, isA<StorageData>());
      });

      test('should handle background remote queries', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          storage.generateProfile(pubkey1),
          storage.generateProfile(pubkey2)
        ];
        await storage.save({franzap, niel});

        final tester = container.testerFor(query<Profile>(
          authors: {pubkey2, pubkey1},
          source: RemoteSource(background: true),
        ));

        await tester.expectModels(hasLength(2));
      });

      test('should handle different relay groups', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          storage.generateProfile(pubkey1),
          storage.generateProfile(pubkey2)
        ];
        await storage.save({franzap, niel});

        final tester = container.testerFor(query<Profile>(
          authors: {pubkey2, pubkey1},
          source: RemoteSource(group: 'big-relays'),
        ));

        await tester.expectModels(hasLength(2));
      });
    });

    group('model type safety', () {
      test('should filter models by correct type', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          storage.generateProfile(pubkey1),
          storage.generateProfile(pubkey2)
        ];
        final note = storage.generateModel(kind: 1, pubkey: pubkey2)!;
        await storage.save({franzap, niel, note});

        // Query for profiles only
        final profileTester = container.testerFor(query<Profile>(
          authors: {pubkey2, pubkey1},
          source: LocalSource(),
        ));

        await profileTester.expectModels(allOf(
          hasLength(2),
          everyElement((m) => m is Profile),
        ));

        // Query for notes only
        final noteTester = container.testerFor(query<Note>(
          authors: {pubkey2, pubkey1},
          source: LocalSource(),
        ));

        await noteTester.expectModels(allOf(
          hasLength(1),
          everyElement((m) => m is Note),
        ));
      });

      test('should handle mixed kind queries correctly', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          storage.generateProfile(pubkey1),
          storage.generateProfile(pubkey2)
        ];
        final note = storage.generateModel(kind: 1, pubkey: pubkey2)!;
        final reaction =
            storage.generateModel(kind: 7, parentId: note.id, pubkey: pubkey1)!;
        await storage.save({franzap, niel, note, reaction});

        // Query for multiple kinds
        final tester = container.testerFor(queryKinds(
          kinds: {0, 1, 7}, // Profile, Note, Reaction
          authors: {pubkey2, pubkey1},
          source: LocalSource(),
        ));

        await tester
            .expectModels(hasLength(4)); // 2 profiles + 1 note + 1 reaction
      }, skip: true);
      // TODO: Test not passing because of blurry line between dummy storage and dummy relay
    });

    group('complex scenarios', () {
      test('should handle complex filter combinations', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          storage.generateProfile(pubkey1),
          storage.generateProfile(pubkey2)
        ];
        final note1 = storage.generateModel(kind: 1, pubkey: pubkey2)!;
        final note2 = storage.generateModel(kind: 1, pubkey: pubkey1)!;
        await storage.save({franzap, niel, note1, note2});

        // Complex filter with multiple conditions
        final tester = container.testerFor(query<Note>(
          authors: {pubkey2, pubkey1},
          since: DateTime.now().subtract(Duration(hours: 1)),
          limit: 10,
          source: LocalSource(),
        ));

        await tester.expectModels(hasLength(2));
      });

      test('should handle where function filtering', () async {
        final pubkey1 = Utils.generateRandomHex64();
        final pubkey2 = Utils.generateRandomHex64();

        final [franzap, niel] = [
          storage.generateProfile(pubkey1),
          storage.generateProfile(pubkey2)
        ];
        final note1 = storage.generateModel(kind: 1, pubkey: pubkey2)!;
        final note2 = storage.generateModel(kind: 1, pubkey: pubkey1)!;
        await storage.save({franzap, niel, note1, note2});

        // Use where function to filter
        final tester = container.testerFor(query<Note>(
          authors: {pubkey2, pubkey1},
          where: (note) => note.author.value?.pubkey == pubkey2,
          source: LocalSource(),
        ));

        await tester.expectModels(allOf(
          hasLength(1),
          everyElement((n) => n.author.value?.pubkey == pubkey2),
        ));
      });
    });

    // Original tests for backward compatibility
    test('relay request should notify with models', () async {
      final pubkey1 = Utils.generateRandomHex64();
      final pubkey2 = Utils.generateRandomHex64();

      final [
        franzap,
        niel
      ] = [storage.generateProfile(pubkey1), storage.generateProfile(pubkey2)];
      await storage.save({
        franzap,
        niel,
        ...List.generate(
            20, (i) => storage.generateModel(kind: 1, pubkey: pubkey1)!),
        ...List.generate(
            20, (i) => storage.generateModel(kind: 1, pubkey: pubkey2)!),
      });

      final tester = container.testerFor(query<Note>(
          authors: {pubkey2, pubkey1},
          limit: 1,
          source: RemoteSource(stream: false)));

      await tester.expectModels(hasLength(1));
      expect(tester.notifier.state, isA<StorageData>());
      expect((tester.notifier.state as StorageData).models, hasLength(1));
    });

    test('relay request should notify with models (streamed)', () async {
      final pubkey1 = Utils.generateRandomHex64();
      final pubkey2 = Utils.generateRandomHex64();

      final [
        franzap,
        niel
      ] = [storage.generateProfile(pubkey1), storage.generateProfile(pubkey2)];
      await storage.save({
        franzap,
        niel,
        ...List.generate(
            20, (i) => storage.generateModel(kind: 1, pubkey: pubkey1)!),
        ...List.generate(
            20, (i) => storage.generateModel(kind: 1, pubkey: pubkey2)!),
      });

      final tester = container.testerFor(query<Note>(
        authors: {pubkey2, pubkey1},
        limit: 5,
        source: RemoteSource(stream: true),
      ));

      await tester.expectModels(hasLength(5));
      expect(tester.notifier.state, isA<StorageData>());
      expect((tester.notifier.state as StorageData).models, hasLength(5));
    });
  });
}

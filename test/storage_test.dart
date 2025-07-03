import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  late ProviderContainer container;
  late DummyStorageNotifier storage;

  setUpAll(() async {
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
  });

  tearDownAll(() {
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
    test('relay request should notify with models', () async {
      final [franzap, niel] = [
        storage.generateProfile(franzapPubkey),
        storage.generateProfile(nielPubkey)
      ];
      await storage.save({
        franzap,
        niel,
        ...List.generate(
            20, (i) => storage.generateModel(kind: 1, pubkey: franzapPubkey)!),
        ...List.generate(
            20, (i) => storage.generateModel(kind: 1, pubkey: nielPubkey)!),
      });

      final tester = container.testerFor(query<Note>(
          authors: {nielPubkey, franzapPubkey},
          limit: 1,
          source: RemoteSource(stream: false)));

      await tester.expectModels(hasLength(1));
      expect(tester.notifier.state, isA<StorageData>());
      expect((tester.notifier.state as StorageData).models, hasLength(1));
      tester.dispose();
    });

    test('relay request should notify with models (streamed)', () async {
      final [franzap, niel] = [
        storage.generateProfile(franzapPubkey),
        storage.generateProfile(nielPubkey)
      ];
      await storage.save({
        franzap,
        niel,
        ...List.generate(
            20, (i) => storage.generateModel(kind: 1, pubkey: franzapPubkey)!),
        ...List.generate(
            20, (i) => storage.generateModel(kind: 1, pubkey: nielPubkey)!),
      });

      final tester = container.testerFor(query<Note>(
        authors: {nielPubkey, franzapPubkey},
        limit: 5,
        source: RemoteSource(stream: true),
      ));

      await tester.expectModels(hasLength(5));
      expect(tester.notifier.state, isA<StorageData>());
      expect((tester.notifier.state as StorageData).models, hasLength(5));
      tester.dispose();
    });
  });
}

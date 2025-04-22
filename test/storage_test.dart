import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  group('storage filters', () {
    late ProviderContainer container;
    late DummyStorageNotifier storage;
    late StateNotifierTester tester;
    late Note a, b, c, d, e, f, g, replyToA, replyToB;
    late Profile nielProfile;

    setUp(() async {
      container = ProviderContainer();
      final config = StorageConfiguration(
        relayGroups: {
          'big-relays': {'wss://damus.relay.io', 'wss://relay.primal.net'}
        },
        defaultRelayGroup: 'big-relays',
        streamingBufferWindow: Duration.zero,
      );
      await container.read(initializationProvider(config).future);
      storage = container.read(storageNotifierProvider.notifier)
          as DummyStorageNotifier;

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
      await storage.save({nielProfile}, relayGroup: 'big-relays');
    });

    tearDown(() async {
      tester.dispose();
      await storage.cancel();
      await storage.clear();
    });

    test('ids', () async {
      tester = container
          .testerFor(queryKinds(ids: {a.event.id, e.event.id}, remote: false));
      await tester.expectModels(unorderedEquals({a, e}));
    });

    test('authors', () async {
      tester = container.testerFor(queryKinds(
          authors: {franzapPubkey, verbirichaPubkey}, remote: false));
      await tester.expectModels(unorderedEquals({e, f, g}));
    });

    test('kinds', () async {
      tester = container.testerFor(query<Note>(remote: false));
      await tester.expectModels(allOf(
        hasLength(9),
        everyElement((e) => e is Model && e.event.kind == 1),
      ));

      tester = container.testerFor(query<Profile>(remote: false));
      await tester.expectModels(hasLength(1));
    });

    test('tags', () async {
      tester = container.testerFor(queryKinds(authors: {
        nielPubkey
      }, tags: {
        '#t': {'nostr'}
      }, remote: false));
      await tester.expectModels(equals({d}));

      tester = container.testerFor(queryKinds(tags: {
        '#t': {'nostr', 'test'}
      }, remote: false));
      await tester.expectModels(unorderedEquals({d, f}));

      tester = container.testerFor(queryKinds(tags: {
        '#t': {'test'}
      }, remote: false));
      await tester.expectModels(isEmpty);

      tester = container.testerFor(queryKinds(tags: {
        '#t': {'nostr'},
        '#e': {nielPubkey}
      }, remote: false));
      await tester.expectModels(isEmpty);
    });

    test('until', () async {
      tester = container.testerFor(query<Note>(
          authors: {nielPubkey},
          until: DateTime.now().subtract(Duration(minutes: 1)),
          remote: false));
      await tester.expectModels(orderedEquals({a, b, replyToB}));
    });

    test('since', () async {
      tester = container.testerFor(queryKinds(
          authors: {nielPubkey},
          since: DateTime.now().subtract(Duration(minutes: 1)),
          remote: false));
      await tester.expectModels(orderedEquals({c, d, nielProfile, replyToA}));
    });

    test('limit and order', () async {
      tester = container.testerFor(
          query<Note>(authors: {nielPubkey}, limit: 3, remote: false));
      await tester.expectModels(orderedEquals({d, c, replyToA}));
    });

    test('replaceable updates', () async {
      tester = container
          .testerFor(query<Profile>(authors: {nielPubkey}, remote: false));
      await tester.expectModels(unorderedEquals({nielProfile}));

      final nielcho =
          nielProfile.copyWith(name: 'Nielcho').dummySign(nielPubkey);
      // Check processMetadata() was called when constructing
      expect(nielcho.name, equals('Nielcho'));
      // Content should NOT be empty as this new event could be sent to relays
      expect(nielcho.event.content, isNotEmpty);
      await nielcho.save();

      await tester.expect(isA<StorageData<Profile>>()
          .having((s) => s.models.first.name, 'name', 'Nielcho'));
    });

    test('relationships with model watcher', () async {
      tester = container
          .testerFor(model(a, and: (note) => {note.author}, remote: false));
      await tester.expectModels(unorderedEquals({a}));
      // NOTE: note.author will be cached, but only note is returned
    });

    test('multiple relationships', () async {
      tester = container.testerFor(query<Note>(
          ids: {a.id, b.id},
          and: (note) => {note.author, note.replies},
          remote: false));
      await tester.expectModels(unorderedEquals({a, b}));
      // NOTE: author and replies will be cached, can't assert here
    });

    test('relay metadata', () async {
      tester = container
          .testerFor(query<Profile>(authors: {nielPubkey}, remote: false));
      await tester.expect(isA<StorageData>()
          .having((s) => s.models.first.event.relays, 'relays', <String>{}));
    });
  });

  group('storage', () {
    late ProviderContainer container;
    late DummyStorageNotifier storage;

    setUpAll(() async {
      container = ProviderContainer();
      final config = StorageConfiguration(
        streamingBufferWindow: Duration.zero,
        maxModels: 100,
      );
      await container.read(initializationProvider(config).future);
      storage = container.read(storageNotifierProvider.notifier)
          as DummyStorageNotifier;
    });

    tearDown(() async {
      // await storage.cancel();
      await storage.clear();
    });

    test('clear with req', () async {
      final a = List.generate(
          30,
          (_) => storage.generateModel(
              kind: 1, createdAt: DateTime.parse('2025-03-12'))!);
      final b = List.generate(30, (_) => storage.generateModel(kind: 1)!);
      await storage.save({...a, ...b});
      final beginOfYear = DateTime.parse('2025-01-01');
      final beginOfMonth = DateTime.parse('2025-04-01');
      expect(
          storage.querySync(RequestFilter(since: beginOfYear)), hasLength(60));
      expect(
          storage.querySync(RequestFilter(since: beginOfMonth)), hasLength(30));
      await storage.clear(RequestFilter(until: beginOfMonth));
      expect(
          storage.querySync(RequestFilter(since: beginOfYear)), hasLength(30));
    });

    test('max models config', () async {
      final max = storage.config.maxModels;
      final a = List.generate(max * 2, (_) => storage.generateModel(kind: 1)!);
      await storage.save(a.toSet());
      expect(storage.querySync(RequestFilter()), hasLength(max));
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
        remote: false,
      );

      expect(r1, equals(r4));
    });

    group('with notifier', () {
      late StateNotifierTester tester;

      tearDown(() async {
        tester.dispose();
      });

      test('relay request should notify with models', () async {
        tester = container.testerFor(
            query<Note>(authors: {nielPubkey, franzapPubkey}, limit: 2));
        await tester.expectModels(isEmpty);
        await tester.expectModels(hasLength(2));
      });

      test('relay request should notify with models (streamed)', () async {
        tester = container.testerFor(query<Note>(
          authors: {nielPubkey, franzapPubkey},
          limit: 5,
          queryLimit: 21,
        ));
        await tester.expectModels(isEmpty); // nothing was in local storage
        await tester.expectModels(hasLength(5)); // limit=5
        // stream starts in batches of 5, until queryLimit=21
        await tester.expectModels(hasLength(10));
        await tester.expectModels(hasLength(15));
        await tester.expectModels(hasLength(20));
        await tester.expectModels(hasLength(21));
      });
    });
  });
}

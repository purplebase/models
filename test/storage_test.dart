import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  late ProviderContainer container;
  late StorageNotifierTester tester;
  late DummyStorageNotifier storage;

  setUpAll(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(
      databasePath: '',
      relayGroups: {
        'big-relays': {'wss://damus.relay.io', 'wss://relay.primal.net'}
      },
      defaultRelayGroup: 'big-relays',
      streamingBufferWindow: Duration.zero,
    );
    await container.read(initializationProvider(config).future);
    storage = container.read(storageNotifierProvider.notifier)
        as DummyStorageNotifier;
  });

  // NOTE: Having no tearDown with cancel() keeps some timers
  // in memory, which help test how request notifiers handle unrelated IDs

  tearDownAll(() async {
    tester.dispose();
    await storage.cancel();
    await storage.clear();
  });

  group('storage filters', () {
    late Note a, b, c, d, e, f, g, replyToA, replyToB;
    late Profile nielProfile;

    setUpAll(() async {
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

    tearDownAll(() async {
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
      // TODO: Implement
      // tester = container
      //     .testerFor(queryKinds(ids: {a.event.id, e.event.id}, remote: false));
      // await tester.expectModels(unorderedEquals({a, e}));
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

  group('storage relay interface', () {
    tearDown(() async {
      tester.dispose();
      await storage.cancel();
      await storage.clear();
    });
    test('request filter', () {
      tester = container.testerFor(query<Reaction>()); // no-op
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
      expect(r1.hash, equals(r2.hash));

      expect(r1.toMap(), isNot(equals(r3.toMap())));
      expect(r1.hash, isNot(equals(r3.hash)));

      // Filter with extra arguments
      final r4 = RequestFilter<Reaction>(
        authors: {nielPubkey, franzapPubkey},
        tags: {
          'foo': {'bar'},
          '#t': {'nostr'}
        },
        remote: false,
        restrictToRelays: true,
      );

      expect(r1.hash, equals(r4.hash));
      expect(r1, equals(r4));
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
}

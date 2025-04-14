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

  tearDownAll(() async {
    tester.dispose();
    await storage.clear();
  });

  group('storage filters', () {
    late Note a, b, c, d, e, f, g, replyToA, replyToB;
    late Profile nielProfile;

    setUpAll(() async {
      final yesterday = DateTime.now().subtract(Duration(days: 1));
      final lastMonth = DateTime.now().subtract(Duration(days: 31));

      a = PartialNote('Note A', createdAt: yesterday).dummySign(niel);
      b = PartialNote('Note B', createdAt: lastMonth).dummySign(niel);
      c = PartialNote('Note C').dummySign(niel);
      d = PartialNote('Note D', tags: {'nostr'}).dummySign(niel);
      e = PartialNote('Note E').dummySign(franzap);
      f = PartialNote('Note F', tags: {'nostr'}).dummySign(franzap);
      g = PartialNote('Note G').dummySign(verbiricha);
      nielProfile = PartialProfile(name: 'neil').dummySign(niel);
      replyToA =
          PartialNote('reply to a', replyTo: a).dummySign(nielProfile.pubkey);
      replyToB = PartialNote('reply to b', createdAt: yesterday, replyTo: b)
          .dummySign(nielProfile.pubkey);

      await storage.save({a, b, c, d, e, f, g, replyToA, replyToB});
      await storage.save({nielProfile}, relayGroup: 'big-relays');
    });

    test('ids', () async {
      tester = container.testerFor(
          query(ids: {a.internal.id, e.internal.id}, storageOnly: true));
      await tester.expectModels(unorderedEquals({a, e}));
    });

    test('authors', () async {
      tester = container
          .testerFor(query(authors: {franzap, verbiricha}, storageOnly: true));
      await tester.expectModels(unorderedEquals({e, f, g}));
    });

    test('kinds', () async {
      tester = container.testerFor(query(kinds: {1}, storageOnly: true));
      await tester.expectModels(allOf(
        hasLength(9),
        everyElement((e) => e is Event && e.internal.kind == 1),
      ));

      tester = container.testerFor(query(kinds: {0}, storageOnly: true));
      await tester.expectModels(hasLength(1));
    });

    test('tags', () async {
      tester = container.testerFor(query(authors: {
        niel
      }, tags: {
        '#t': {'nostr'}
      }, storageOnly: true));
      await tester.expectModels(equals({d}));

      tester = container.testerFor(query(tags: {
        '#t': {'nostr', 'test'}
      }, storageOnly: true));
      await tester.expectModels(unorderedEquals({d, f}));

      tester = container.testerFor(query(tags: {
        '#t': {'test'}
      }, storageOnly: true));
      await tester.expectModels(isEmpty);

      tester = container.testerFor(query(tags: {
        '#t': {'nostr'},
        '#e': {niel}
      }, storageOnly: true));
      await tester.expectModels(isEmpty);
    });

    test('until', () async {
      tester = container.testerFor(query(
          kinds: {1},
          authors: {niel},
          until: DateTime.now().subtract(Duration(minutes: 1)),
          storageOnly: true));
      await tester.expectModels(orderedEquals({a, b, replyToB}));
    });

    test('since', () async {
      tester = container.testerFor(query(
          authors: {niel},
          since: DateTime.now().subtract(Duration(minutes: 1)),
          storageOnly: true));
      await tester.expectModels(orderedEquals({c, d, nielProfile, replyToA}));
    });

    test('limit and order', () async {
      tester = container.testerFor(
          query(kinds: {1}, authors: {niel}, limit: 3, storageOnly: true));
      await tester.expectModels(orderedEquals({d, c, replyToA}));
    });

    test('relationships with model watcher', () async {
      tester = container
          .testerFor(model(a, and: (note) => {note.author}, storageOnly: true));
      await tester.expectModels(unorderedEquals({a}));
      // NOTE: note.author will be cached, but only note is returned
    });

    test('multiple relationships', () async {
      tester = container.testerFor(queryType<Note>(
          ids: {a.id, b.id},
          and: (note) => {note.author, note.replies},
          storageOnly: true));
      await tester.expectModels(unorderedEquals({a, b}));
      // NOTE: author and replies will be cached, can't assert here
    });

    test('relay metadata', () async {
      tester = container
          .testerFor(queryType<Profile>(authors: {niel}, storageOnly: true));
      await tester.expect(isA<StorageData>()
          .having((s) => s.models.first.internal.relays, 'relays', <String>{}));
    });
  });

  // TODO: Fix tests
  group('storage relay interface', () {
    tearDown(() async {
      tester.dispose();
      await storage.clear();
    });
    test('request filter', () {
      tester = container.testerFor(query()); // no-op
      final r1 = RequestFilter(kinds: {
        7
      }, authors: {
        niel,
        franzap
      }, tags: {
        'foo': {'bar'},
        '#t': {'nostr'}
      });
      final r2 = RequestFilter(kinds: {
        7
      }, authors: {
        franzap,
        niel
      }, tags: {
        '#t': {'nostr'},
        'foo': {'bar'}
      });
      final r3 = RequestFilter(kinds: {
        7
      }, authors: {
        franzap,
        niel
      }, tags: {
        'foo': {'bar'}
      });
      expect(r1, equals(r2));
      expect(r1.toMap(), equals(r2.toMap()));
      expect(r1.hash, equals(r2.hash));

      expect(r1.toMap(), isNot(equals(r3.toMap())));
      expect(r1.hash, isNot(equals(r3.hash)));

      // Filter with extra arguments
      final r4 = RequestFilter(
        kinds: {7},
        authors: {niel, franzap},
        tags: {
          'foo': {'bar'},
          '#t': {'nostr'}
        },
        storageOnly: true,
        restrictToRelays: true,
      );

      expect(r1.hash, equals(r4.hash));
      expect(r1, equals(r4));
    });

    test('relay request should notify with events', () async {
      tester = container
          .testerFor(query(kinds: {1}, authors: {niel, franzap}, limit: 2));
      await tester.expectModels(isEmpty); // nothing was in local storage
      await tester.expectModels(hasLength(2)); // limit
    });

    test('relay request should notify with events (streamed)', () async {
      tester = container.testerFor(query(
          kinds: {1}, authors: {niel, franzap}, limit: 5, queryLimit: 11));
      await tester.expectModels(isEmpty); // nothing was in local storage
      await tester.expectModels(hasLength(5)); // limit
      await tester.expectModels(hasLength(10)); // 5 more streamed
      await tester
          .expectModels(hasLength(11)); // 1 more streamed to reach to 11
    });
  });
}

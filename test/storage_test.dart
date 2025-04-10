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
        defaultRelayGroup: 'big-relays');
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
      tester = container.testerFor(query(ids: {a.internal.id, e.internal.id}));
      await tester.expectModels(unorderedEquals({a, e}));
    });

    test('authors', () async {
      tester = container.testerFor(query(authors: {franzap, verbiricha}));
      await tester.expectModels(unorderedEquals({e, f, g}));
    });

    test('kinds', () async {
      tester = container.testerFor(query(kinds: {1}));
      await tester.expectModels(allOf(
        hasLength(9),
        everyElement((e) => e is Event && e.internal.kind == 1),
      ));

      tester = container.testerFor(query(kinds: {0}));
      await tester.expectModels(hasLength(1));
    });

    test('tags', () async {
      tester = container.testerFor(query(authors: {
        niel
      }, tags: {
        '#t': {'nostr'}
      }));
      await tester.expectModels(equals({d}));

      tester = container.testerFor(query(tags: {
        '#t': {'nostr', 'test'}
      }));
      await tester.expectModels(unorderedEquals({d, f}));

      tester = container.testerFor(query(tags: {
        '#t': {'test'}
      }));
      await tester.expectModels(isEmpty);

      tester = container.testerFor(query(tags: {
        '#t': {'nostr'},
        '#e': {'a1b2c3'}
      }));
      await tester.expectModels(isEmpty);
    });

    test('until', () async {
      tester = container.testerFor(query(
          kinds: {1},
          authors: {niel},
          until: DateTime.now().subtract(Duration(minutes: 1))));
      await tester.expectModels(orderedEquals({a, b, replyToB}));
    });

    test('since', () async {
      tester = container.testerFor(query(
          authors: {niel},
          since: DateTime.now().subtract(Duration(minutes: 1))));
      await tester.expectModels(orderedEquals({c, d, nielProfile, replyToA}));
    });

    test('limit and order', () async {
      tester =
          container.testerFor(query(kinds: {1}, authors: {niel}, limit: 3));
      await tester.expectModels(orderedEquals({d, c, replyToA}));
    });

    test('relationships with model watcher', () async {
      tester = container.testerFor(model(a, and: (note) => {note.author}));
      await tester.expectModels(unorderedEquals({a, nielProfile}));
    });

    test('multiple relationships', () async {
      tester = container.testerFor(queryType<Note>(
          ids: {a.id, b.id}, and: (note) => {note.author, note.replies}));
      await tester.expectModels(
          unorderedEquals({a, b, nielProfile, replyToA, replyToB}));
    });

    test('relay metadata', () async {
      tester = container.testerFor(queryType<Profile>(authors: {niel}));
      await tester.expect(isA<StorageData>()
          .having((s) => s.models.first.internal.relays, 'relays', <String>{}));
    });
  });

  group('storage relay interface', () {
    test('request filter', () {
      tester = container.testerFor(query()); // no-op
      final r1 = RequestFilter(kinds: {
        7
      }, authors: {
        'a',
        'b'
      }, tags: {
        'foo': {'bar'},
        '#t': {'nostr'}
      });
      final r2 = RequestFilter(kinds: {
        7
      }, authors: {
        'b',
        'a'
      }, tags: {
        '#t': {'nostr'},
        'foo': {'bar'}
      });
      final r3 = RequestFilter(kinds: {
        7
      }, authors: {
        'b',
        'a'
      }, tags: {
        'foo': {'bar'}
      });
      expect(r1, equals(r2));
      expect(r1.toMap(), equals(r2.toMap()));
      expect(r1.hash, equals(r2.hash));

      expect(r1.toMap(), isNot(equals(r3.toMap())));
      expect(r1.hash, isNot(equals(r3.hash)));
    });

    test('relay request should notify with events', () async {
      tester =
          container.testerFor(query(kinds: {1}, authors: {'a', 'b'}, limit: 2));
      await tester.expectModels(isEmpty);

      await storage.generateDummyFor(pubkey: 'a', kind: 1, amount: 4);
      await tester.expect(isA<StorageLoading>());
      await tester.expectModels(hasLength(4));
    });
  });
}

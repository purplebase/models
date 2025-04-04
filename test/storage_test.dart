import 'package:models/models.dart';
import 'package:models/src/storage/dummy_notifier.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  late ProviderContainer container;
  late StorageNotifierTester tester;
  late DummyStorageNotifier storage;

  setUpAll(() async {
    container = ProviderContainer();
    await container.read(initializationProvider(StorageConfiguration()).future);
    storage = container.read(storageNotifierProvider.notifier)
        as DummyStorageNotifier;
  });

  tearDownAll(() async {
    tester.dispose();
    await storage.clear();
  });

  group('storage filters', () {
    late Note a, b, c, d, e, f, g, replyToA, replyToB;
    late Profile profile;

    setUpAll(() async {
      final yesterday = DateTime.now().subtract(Duration(days: 1));
      final lastMonth = DateTime.now().subtract(Duration(days: 31));

      a = await PartialNote('Note A', createdAt: yesterday).by('niel');
      b = await PartialNote('Note B', createdAt: lastMonth).by('niel');
      c = await PartialNote('Note C').by('niel');
      d = await PartialNote('Note D', tags: {'nostr'}).by('niel');
      e = await PartialNote('Note E').by('franzap');
      f = await PartialNote('Note F', tags: {'nostr'}).by('franzap');
      g = await PartialNote('Note G').by('verbiricha');
      profile = await PartialProfile(name: 'neil').by('niel');
      final partialReplyToA = PartialNote('reply to a')
        ..linkEvent(a, marker: EventMarker.root);
      final partialReplyToB = PartialNote('reply to b', createdAt: yesterday)
        ..linkEvent(b, marker: EventMarker.root);
      replyToA = await partialReplyToA.by(profile.pubkey);
      replyToB = await partialReplyToB.by(profile.pubkey);

      await storage.save({a, b, c, d, e, f, g, profile, replyToA, replyToB});
    });

    test('ids', () async {
      tester = container.testerFor(query(ids: {a.internal.id, e.internal.id}));
      await tester.expectModels(unorderedEquals({a, e}));
    });

    test('authors', () async {
      tester = container.testerFor(query(authors: {'franzap', 'verbiricha'}));
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
        'niel'
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
          authors: {'niel'},
          until: DateTime.now().subtract(Duration(minutes: 1))));
      await tester.expectModels(orderedEquals({a, b, replyToB}));
    });

    test('since', () async {
      tester = container.testerFor(query(
          authors: {'niel'},
          since: DateTime.now().subtract(Duration(minutes: 1))));
      await tester.expectModels(orderedEquals({c, d, profile, replyToA}));
    });

    test('limit and order', () async {
      tester =
          container.testerFor(query(kinds: {1}, authors: {'niel'}, limit: 3));
      await tester.expectModels(orderedEquals({d, c, replyToA}));
    });

    test('relationships with model watcher', () async {
      tester = container.testerFor(model(a, and: (note) => {note.author}));
      await tester.expectModels(unorderedEquals({a, profile}));
    });

    test('multiple relationships', () async {
      tester = container.testerFor(queryType<Note>(
          ids: {a.id, b.id}, and: (note) => {note.author, note.replies}));
      await tester
          .expectModels(unorderedEquals({a, b, profile, replyToA, replyToB}));
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
      // First state is existing in storage
      await tester.expectModels(isEmpty);

      await storage.generateDummyFor(pubkey: 'a', kind: 1, amount: 4);
      await tester.expect(isA<StorageLoading>());

      final nModels = 5; // limit * number of authors
      await tester.expectModels(hasLength(nModels));
    });

    test('', () {
      // tester.notifier.send(RequestFilter(authors: {'a'}));

      // final note =
      //     await PartialNote('yo').signWith(DummySigner(), withPubkey: 'a');
      // relay.publish(note);
    });
  });
}

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  late ProviderContainer container;
  late StorageNotifierTester tester;

  setUpAll(() async {
    container = ProviderContainer();
    await container.read(initializationProvider.future);
  });
  tearDownAll(() => tester.dispose());

  group('storage filters', () {
    late Note a, b, c, d, e, f, g;
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

      container.read(dummyDataProvider.notifier).state = [
        a,
        b,
        c,
        d,
        e,
        f,
        g,
        profile
      ];
    });

    test('ids', () async {
      tester = container.testerFor(query(ids: {a.event.id, e.event.id}));
      await tester.expectModels(unorderedEquals({a, e}));
    });

    test('authors', () async {
      tester = container.testerFor(query(authors: {'franzap', 'verbiricha'}));
      await tester.expectModels(unorderedEquals({e, f, g}));
    });

    test('kinds', () async {
      tester = container.testerFor(query(kinds: {1}));
      await tester.expectModels(allOf(
        hasLength(7),
        everyElement((e) => e is Event && e.event.kind == 1),
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
    });

    test('until', () async {
      tester = container.testerFor(query(
          kinds: {1},
          authors: {'niel'},
          until: DateTime.now().subtract(Duration(minutes: 1))));
      await tester.expectModels(orderedEquals({a, b}));
    });

    test('since', () async {
      tester = container.testerFor(query(
          authors: {'niel'},
          since: DateTime.now().subtract(Duration(minutes: 1))));
      await tester.expectModels(orderedEquals({c, d, profile}));
    });

    test('limit and order', () async {
      tester =
          container.testerFor(query(kinds: {1}, authors: {'niel'}, limit: 3));
      await tester.expectModels(orderedEquals({d, c, a}));
    });

    test('relationships', () {
      tester = container.testerFor(query());
      expect(a.profile.value, profile);
      expect(profile.notes.toList(), unorderedEquals({a, b, c, d}));
    });
  });

  test('relay request should notify with events', () async {
    tester =
        container.testerFor(query(kinds: {1}, authors: {'a', 'b'}, limit: 2));
    // First state is existing in storage
    await tester.expectModels(isEmpty);
    // As query hits relays and dummy creates fake ones, they come in via storage
    final nModels = 4; // limit * number of authors
    await tester.expectModels(hasLength(nModels));
  });

  test('', () {
    // tester.notifier.send(RequestFilter(authors: {'a'}));

    // final note =
    //     await PartialNote('yo').signWith(DummySigner(), withPubkey: 'a');
    // relay.publish(note);
  });
}

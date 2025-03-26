import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  late ProviderContainer container;
  setUpAll(() async {
    container = ProviderContainer();
    await container.read(initializationProvider.future);
  });

  group('event', () {
    test('from partial event', () async {
      const pk =
          'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8';
      final signer = Bip340PrivateKeySigner(pk);

      final defaultEvent = PartialApp()
        ..name = 'app'
        ..identifier = 'w';
      print(defaultEvent.toMap());
      // expect(defaultEvent.isValid, isFalse);

      final t = DateTime.parse('2024-07-26');
      final signedEvent = await signer.sign(PartialApp()
        ..name = 'tr'
        ..internal.createdAt = t
        ..identifier = 's1');
      // expect(signedEvent.isValid, isTrue);
      print(signedEvent.toMap());

      final signedEvent2 = await signer.sign(PartialApp()
        ..name = 'tr'
        ..identifier = 's1'
        ..internal.createdAt = t);
      // expect(signedEvent2.isValid, isTrue);
      print(signedEvent2.toMap());
      // Test equality
      expect(signedEvent, signedEvent2);
    });

    test('tags', () {
      final note = PartialNote('yo hello');
      note.internal.addTagValue('url', 'http://z');
      note.internal
          .addTag('e', EventTagValue('93893923', marker: EventMarker.mention));
      note.internal.addTagValue('e', 'ab9387');
      note.internal.addTag('param', TagValue(['a', '1']));
      note.internal.addTag('param', TagValue(['a', '2']));
      note.internal.addTag('param', TagValue(['a', '3']));

      print(note.toMap());
      note.internal.addTag('param', TagValue(['b', '4']));
      note.internal.removeTagWithValue('e');
      expect(note.internal.containsTag('e'), isFalse);
      expect(note.internal.getFirstTagValue('url'), 'http://z');
      print(note.toMap());
    });
  });

  group('models', () {
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

    test('note and relationships', () async {
      expect(a.author.value, profile);
      expect(profile.notes.toList(), orderedEquals({a, b, c, d}));
      expect(profile.notes.toList(limit: 2), orderedEquals({c, d}));

      final replyPartialNote = PartialNote('replying')
        ..linkEvent(c, marker: EventMarker.root);
      final replyNote = await replyPartialNote.by('foo');

      final replyToReplyPartialNote = PartialNote('replying to reply')
        ..linkEvent(replyNote, marker: EventMarker.reply)
        ..linkEvent(c, marker: EventMarker.root);
      final replyToReplyNote = await replyToReplyPartialNote.by('bar');

      await container.read(storageProvider).save({replyNote, replyToReplyNote});
      expect(c.notes.toList(), {replyNote});
      expect(c.allNotes.toList(), {replyNote, replyToReplyNote});

      final reaction =
          await PartialReaction(reactedOn: a, emojiTag: ('test', 'test://t'))
              .by('niel');
      expect(reaction.internal.getFirstTag('emoji'),
          equals(TagValue(['test', 'test://t'])));
      expect(reaction.reactedOn.ids, {a.internal.id});
      expect(reaction.reactedOn.value, a);
      expect(reaction.author.value, profile);
    });

    test('profile', () async {
      final p1 = await PartialProfile(
        name: 'Niel Liesmons',
        pictureUrl:
            'https://cdn.satellite.earth/946822b1ea72fd3710806c07420d6f7e7d4a7646b2002e6cc969bcf1feaa1009.png',
      ).by('niel');
      expect(p1.internal.content,
          '{"name":"Niel Liesmons","nip05":null,"picture":"https://cdn.satellite.earth/946822b1ea72fd3710806c07420d6f7e7d4a7646b2002e6cc969bcf1feaa1009.png"}');
    });

    test('app', () async {
      final partialApp = PartialApp()
        ..identifier = 'w'
        ..description = 'test app';
      final app = await partialApp
          .by('gordo'); // identifier: 'blah'; pubkeys: {'90983aebe92bea'}
      // expect(app.isValid, isTrue);
      expect(app.internal.kind, 32267);
      expect(app.description, 'test app');
      // expect(app.identifier, 'blah');
      // expect(app.getReplaceableEventLink(), (
      //   32267,
      //   'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1',
      //   'blah'
      // ));
      // expect(app.pubkeys, {'90983aebe92bea'});
      // expect(App.fromMap(app.toMap()), app);

      // event and partial event should share a common interface
      // final apps = [partialApp, app];
      // apps.first.repository;

      // final note = await PartialNote().signWith(signer);
      // final List<EventBase> notes = [PartialNote(), note];
      // notes.first.event.content;
    });
  });
}

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  setUpAll(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
  });

  group('Note', () {
    test('from/to partial model', () async {
      const pk =
          'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8';
      final signer = Bip340PrivateKeySigner(pk, container.read(refProvider));
      signer.initialize();

      final t = DateTime.parse('2024-07-26');
      final [signedNote, signedNote2] = await signer.sign<Note>([
        PartialNote('tr')..event.createdAt = t,
        PartialNote('tr')..event.createdAt = t
      ]);

      expect(signedNote, signedNote2);

      final partialNote = signedNote.toPartial();
      expect(await partialNote.signWith(signer), signedNote);
    });

    test('tags', () {
      final note = PartialNote('yo hello');
      note.event.addTagValue('url', 'http://z');
      note.event.addTag('e', ['93893923', '', 'mention']);
      note.event.addTagValue('e', 'ab9387');
      note.event.addTag('param', ['a', '1']);
      note.event.addTag('param', ['a', '2']);
      note.event.addTag('param', ['a', '3']);

      note.event.addTag('param', ['b', '4']);
      note.event.removeTagWithValue('e');
      expect(note.event.containsTag('e'), isFalse);
      expect(note.event.getFirstTagValue('url'), 'http://z');
    });

    test('note and relationships', () async {
      late Note a, b, c, d, e, f, g;
      late Profile profile;
      late DummyStorageNotifier storage;

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
      profile = PartialProfile(name: 'neil').dummySign(nielPubkey);

      await storage.save({a, b, c, d, e, f, g, profile});

      expect(a.author.value, profile);
      expect(profile.notes.toList(), orderedEquals({a, b, c, d}));

      final replyNote =
          PartialNote('replying', replyTo: c).dummySign(franzapPubkey);

      final replyToReplyNote =
          PartialNote('replying to reply', replyTo: replyNote, root: c)
              .dummySign(verbirichaPubkey);

      await container
          .read(storageNotifierProvider.notifier)
          .save({replyNote, replyToReplyNote});

      expect(c.isRoot, isTrue);
      expect(c.root.value, isNull);
      expect(replyNote.root.value, c);
      expect(replyToReplyNote.root.value, c);
      expect(c.replies.toList(), {replyNote});
      expect(c.allReplies.toList(), {replyNote, replyToReplyNote});

      expect(c.replyTo.value, isNull); // Root note has no replyTo
      expect(replyNote.replyTo.value, c); // Direct reply points to root
      expect(replyToReplyNote.replyTo.value,
          replyNote); // Nested reply points to immediate parent
    });

    test('complex threading with root and reply markers', () async {
      late Note rootNote, intermediateNote, complexReplyNote;
      late DummyStorageNotifier storage;

      storage = container.read(storageNotifierProvider.notifier)
          as DummyStorageNotifier;

      // Create a root note
      rootNote = PartialNote('Root note content').dummySign(nielPubkey);

      // Create an intermediate note that replies to root
      intermediateNote = PartialNote('Intermediate reply', replyTo: rootNote)
          .dummySign(franzapPubkey);

      await storage.save({rootNote, intermediateNote});

      // Create a complex note that has both root and reply markers
      // Simulating the event structure from the provided data
      final complexReply = PartialNote('Complex reply with both markers');

      // Manually add both root and reply e tags to simulate the complex scenario
      complexReply.event.addTag('e', [rootNote.event.id, '', 'root']);
      complexReply.event.addTag('e', [intermediateNote.event.id, '', 'reply']);

      complexReplyNote = complexReply.dummySign(verbirichaPubkey);

      await storage.save({complexReplyNote});

      // Test the complex threading relationships
      expect(rootNote.isRoot, isTrue);
      expect(rootNote.root.value, isNull);
      expect(rootNote.replyTo.value, isNull);

      expect(intermediateNote.isRoot, isFalse);
      expect(intermediateNote.root.value, rootNote);
      expect(intermediateNote.replyTo.value, rootNote); // Direct reply to root

      expect(complexReplyNote.isRoot, isFalse);
      expect(
          complexReplyNote.root.value, rootNote); // Root marker points to root
      expect(complexReplyNote.replyTo.value,
          intermediateNote); // Reply marker points to intermediate

      // Test the HasMany relationships
      expect(rootNote.allReplies.toList(),
          containsAll([intermediateNote, complexReplyNote]));
      expect(intermediateNote.allReplies.toList(),
          isEmpty); // No replies to intermediate
    });
  });
}

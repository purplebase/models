import 'dart:convert';

import 'package:models/models.dart';
import 'package:models/src/storage/dummy_notifier.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  late ProviderContainer container;
  setUpAll(() async {
    container = ProviderContainer();
    await container.read(initializationProvider(StorageConfiguration()).future);
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
    late DummyStorageNotifier storage;

    setUpAll(() async {
      storage = container.read(storageNotifierProvider.notifier)
          as DummyStorageNotifier;
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

      storage.save({a, b, c, d, e, f, g, profile});
    });

    test('note and relationships', () async {
      expect(a.author.value, profile);
      expect(profile.notes.toList(), orderedEquals({a, b, c, d}));
      expect(profile.notes.toList(limit: 2), orderedEquals({c, d}));

      // TODO: Replace all this with replyTo in PartialNote
      final replyPartialNote = PartialNote('replying')
        ..linkEvent(c, marker: EventMarker.root);
      final replyNote = await replyPartialNote.by('foo');

      final replyToReplyPartialNote = PartialNote('replying to reply')
        ..linkEvent(replyNote, marker: EventMarker.reply)
        ..linkEvent(c, marker: EventMarker.root);
      final replyToReplyNote = await replyToReplyPartialNote.by('bar');

      await container
          .read(storageNotifierProvider.notifier)
          .save({replyNote, replyToReplyNote});
      expect(c.replies.toList(), {replyNote});
      expect(c.allReplies.toList(), {replyNote, replyToReplyNote});

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
      final niel = await PartialProfile(
        name: 'Niel Liesmons',
        pictureUrl:
            'https://cdn.satellite.earth/946822b1ea72fd3710806c07420d6f7e7d4a7646b2002e6cc969bcf1feaa1009.png',
      ).by('a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be');

      expect(niel.internal.content,
          '{"name":"Niel Liesmons","nip05":null,"picture":"https://cdn.satellite.earth/946822b1ea72fd3710806c07420d6f7e7d4a7646b2002e6cc969bcf1feaa1009.png"}');
      print(niel.internal.shareableId);
    });

    test('app', () async {
      final partialApp = PartialApp()
        ..identifier = 'w'
        ..description = 'test app';
      final app = await partialApp.by(
          'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1');

      expect(app.internal.kind, 32267);
      expect(app.description, 'test app');
      expect(app.id,
          '32267:f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1:w');
      expect(app.internal.id, hasLength(64));
      expect(app.internal.shareableId,
          'naddr1qqqhwq3q7dh35fe8k74s9clkaxvyrnftfkt9t7x05xzt6ntg7njvwtdcuhqsxpqqqplqknw8nmm');
      expect(App.fromMap(app.toMap(), container.read(refProvider)), app);
    });

    test('zaps', () async {
      final ref = container.read(refProvider);
      final author = await PartialProfile().by(
          'd3f94b353542a632962062f3c914638d0deeba64af1f980d93907ee1b3e0d4f9');
      final zap = Zap.fromMap(jsonDecode(zapJson), ref);
      final event = Note.fromMap(jsonDecode(zappedEventJson), ref);
      await storage.save({event, zap, author});
      expect(zap.zappedEvent.value, event);
      expect(zap.author.value, author);
    });
  });
}

final zapJson = '''
{
        "content": "Onward 🫡",
        "created_at": 1743797169,
        "id": "707193656edaab92fbd3ebbcfa381ab011bcc8dbce17260a1198b81294879d53",
        "kind": 9735,
        "pubkey": "79f00d3f5a19ec806189fcab03c1be4ff81d18ee4f653c88fac41fe03570f432",
        "sig": "e7a68c7a18827a9a46b9d8d125feff4094314ecb2aee2698f8a922bd35631bc36aca07e0bff7a37b791fb886a59189480d4ba872c86ff84b6f54e9d5a3418b00",
        "tags": [
            [
                "p",
                "83e818dfbeccea56b0f551576b3fd39a7a50e1d8159343500368fa085ccd964b"
            ],
            [
                "e",
                "be000cd2f9c727040bf8f776977ae13932206b183c7683f3577dbd34a0527265"
            ],
            [
                "P",
                "d3f94b353542a632962062f3c914638d0deeba64af1f980d93907ee1b3e0d4f9"
            ],
            [
                "bolt11",
                "lnbc100n1pnlqwa9dqjfah8wctjvss0p8at5ynp4qgu7jqu20szcefctv9svpr8cluupxytk4uvnenhs9rht9xnpca8c7pp5ey6n62thnvc80pqq6grat8wtjjnp5q8ufzrpkywszfmjm7aa65gssp5huu4yflauez92htgshdc626d2aptj6nzzxu0c8m4meq7cl47un4q9qyysgqcqpcxqyz5vqrzjqw9fu4j39mycmg440ztkraa03u5qhtuc5zfgydsv6ml38qd4azymlapyqqqqqqqguuqqqqlgqqqq86qqjqrzjqvdnqyc82a9maxu6c7mee0shqr33u4z9z04wpdwhf96gxzpln8jcrapyqqqqqqpjzgqqqqqqqqqqqqqq2qugr78ycykysvtpjzycm9ak5r7cuwurqazjpf0l73ypxp6dd7vyssxyx74ycss3umen02d97uvdhkd0kyn87hfmmsqqzhmculsc234kgqhdjvdr"
            ],
            [
                "preimage",
                "00bacd14f94ea03c10267c34a01e51b15ce0fbdc6506ebe35054c17fecb31407"
            ],
            [
                "description",
                "{\\"id\\":\\"24783f6c0c60c72e444306fa5e3d71d4e3d01db8618daeccb5047b1714cd17b1\\",\\"pubkey\\":\\"d3f94b353542a632962062f3c914638d0deeba64af1f980d93907ee1b3e0d4f9\\",\\"created_at\\":1743797156,\\"kind\\":9734,\\"tags\\":[[\\"e\\",\\"be000cd2f9c727040bf8f776977ae13932206b183c7683f3577dbd34a0527265\\"],[\\"p\\",\\"83e818dfbeccea56b0f551576b3fd39a7a50e1d8159343500368fa085ccd964b\\"],[\\"relays\\",\\"wss://relay.primal.net\\",\\"wss://relay.damus.io\\",\\"wss://relay.nostr.band\\",\\"wss://relay.current.fyi\\",\\"wss://purplepag.es\\",\\"wss://nos.lol\\",\\"wss://offchain.pub\\",\\"wss://nostr.bitcoiner.social\\"]],\\"content\\":\\"Onward 🫡\\",\\"sig\\":\\"516a51fb761b0dcd262069da90f25d7a767624c42ff688b70d8504e144964a8bb5da25fb9e429692cd1dd487487de961884086f7ae6da2443b6948604a6011ef\\"}"
            ]
        ]
    }
''';

final zappedEventJson = '''
{
        "content": "Those measuring the system from inside of it are likely very confused today. \\n\\n#bitcoin",
        "created_at": 1743788815,
        "id": "be000cd2f9c727040bf8f776977ae13932206b183c7683f3577dbd34a0527265",
        "kind": 1,
        "pubkey": "83e818dfbeccea56b0f551576b3fd39a7a50e1d8159343500368fa085ccd964b",
        "sig": "5da5de9caf7c7b4579bb8c5a818664ee26d361b50fed59a1c66a82fffd028ffdd34e2927e58c50bd6e95477e19102e96147d7355d8eac7c8d1311e8ab15a4cd8",
        "tags": [
            [
                "t",
                "bitcoin"
            ]
        ]
    }
''';

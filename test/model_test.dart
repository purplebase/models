import 'dart:convert';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;
  setUpAll(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
  });

  group('model', () {
    test('from partial model', () async {
      const pk =
          'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8';
      final signer = Bip340PrivateKeySigner(pk, container.read(refProvider));
      signer.initialize();

      final t = DateTime.parse('2024-07-26');
      final [signedModel, signedModel2] = await signer.sign([
        PartialApp()
          ..name = 'tr'
          ..event.createdAt = t
          ..identifier = 's1',
        PartialApp()
          ..name = 'tr'
          ..identifier = 's1'
          ..event.createdAt = t
      ]);

      expect(signedModel, signedModel2);
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
  });

  group('models', () {
    late Note a, b, c, d, e, f, g;
    late Profile profile;
    late DummyStorageNotifier storage;
    late Ref ref;

    setUpAll(() async {
      ref = container.read(refProvider);
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
    });

    test('note and relationships', () async {
      expect(a.author.value, profile);
      expect(profile.notes.toList(), orderedEquals({a, b, c, d}));

      final replyNote =
          PartialNote('replying', replyTo: c).dummySign(franzapPubkey);

      final replyToReplyNote =
          PartialNote('replying to reply', replyTo: replyNote)
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

      final reaction =
          PartialReaction(reactedOn: a, emojiTag: ('test', 'test://t'))
              .dummySign(nielPubkey);
      expect(reaction.emojiTag, equals(('test', 'test://t')));
      expect(reaction.reactedOn.req!.ids, {a.event.id});
      expect(reaction.reactedOn.value, a);
      expect(reaction.author.value, profile);
    });

    test('profile & contact list', () async {
      final nielProfile = PartialProfile(
        name: 'Niel Liesmons',
        pictureUrl:
            'https://cdn.satellite.earth/946822b1ea72fd3710806c07420d6f7e7d4a7646b2002e6cc969bcf1feaa1009.png',
      ).dummySign(nielPubkey);

      expect(nielProfile.event.content,
          '{"name":"Niel Liesmons","picture":"https://cdn.satellite.earth/946822b1ea72fd3710806c07420d6f7e7d4a7646b2002e6cc969bcf1feaa1009.png"}');
      expect(nielProfile.event.shareableId,
          'nprofile1qqs2js6wu9j76qdjs6lvlsnhrmchqhf4xlg9rvu89zyf3nqq6hygt0sty4s8y');

      final franzapProfile = Profile.fromMap(jsonDecode(franzapJson), ref);
      final verbirichaProfile =
          Profile.fromMap(jsonDecode(verbirichaJson), ref);
      final nielContactList = (PartialContactList()
            ..addFollow(franzapProfile)
            ..addFollow(verbirichaProfile))
          .dummySign(nielProfile.pubkey);

      await storage.save({franzapProfile, verbirichaProfile, nielContactList});

      expect(nielProfile.contactList.value!.following.toList(),
          {franzapProfile, verbirichaProfile});
    });

    test('article', () {
      final article = PartialArticle(
        'title',
        'Content of the article',
        slug: 'yo',
        summary: 'summary',
        publishedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ).dummySign(verbirichaPubkey);
      expect(article.imageUrl, isNull);
      expect(article.slug, 'yo');
      expect(article.title, 'title');
    });

    test('app', () {
      final partialApp = PartialApp()
        ..identifier = 'w'
        ..description = 'test app';
      final app = partialApp.dummySign(
          'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1');

      expect(app.event.kind, 32267);
      expect(app.description, 'test app');
      expect(app.id,
          '32267:f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1:w');
      expect(app.event.id, hasLength(64));
      expect(app.event.shareableId,
          'naddr1qqqhwq3q7dh35fe8k74s9clkaxvyrnftfkt9t7x05xzt6ntg7njvwtdcuhqsxpqqqplqknw8nmm');
      expect(App.fromMap(app.toMap(), ref), app);
    });

    test('zaps', () async {
      final author = PartialProfile().dummySign(
          'd3f94b353542a632962062f3c914638d0deeba64af1f980d93907ee1b3e0d4f9');
      final zap = Zap.fromMap(jsonDecode(zapJson), ref);
      final note = Note.fromMap(jsonDecode(zappedEventJson), ref);
      await storage.save({note, zap, author});
      // As config is keepSignatures=false, it should come back as null
      expect(zap.zappedModel.value!.event.signature, isNull);
      expect(zap.zappedModel.value, note);
      expect(zap.author.value, author);
    });

    test('community', () async {
      final community = PartialCommunity(
        name: 'communikey',
        createdAt: DateTime.parse('2025-04-10'),
        description: 'Some cool shit',
        relayUrls: {'wss://communi.key'},
        blossomUrls: {'https://cdn.communi.key'},
        contentSections: {
          CommunityContentSection(content: 'Chat', kinds: {9}),
          CommunityContentSection(
              content: 'Post', kinds: {1, 11}, feeInSats: 10),
          CommunityContentSection(
              content: 'Article', kinds: {30023, 30040}, feeInSats: 21),
        },
        termsOfService: 'https://tos',
      ).dummySign(nielPubkey);

      expect(community.author.value!.pubkey, nielPubkey);

      final community2 = Community.fromMap(community.toMap(), ref);
      expect(community.toMap(), community2.toMap());
      expect(jsonDecode(communityJson), community2.toMap());

      final note = PartialNote('test').dummySign();
      final targetedPublication =
          PartialTargetedPublication(note, communities: {community})
              .dummySign();
      await storage.save({community, note, targetedPublication});
      expect(targetedPublication.communities.toList(), [community]);
      expect(targetedPublication.model.value, note);
      expect(targetedPublication.event.identifier, hasLength(64));
    });

    test('comment', () async {
      // Create test content to comment on
      final article = PartialArticle(
        'Test Article',
        'Article content for testing comments',
        slug: 'test-article',
        summary: 'Test article summary',
      ).dummySign(nielPubkey);

      final fileMetadata = PartialFileMetadata().dummySign(franzapPubkey);

      // Create comments on different content types
      final articleComment = PartialComment(
        content: 'Comment on an article',
        rootModel: article,
        parentModel: article,
      ).dummySign(verbirichaPubkey);

      final fileComment = PartialComment(
        content: 'Comment on a file',
        rootModel: fileMetadata,
        parentModel: fileMetadata,
      ).dummySign(nielPubkey);

      // Save base models first
      await storage.save({article, fileMetadata});

      // Save comments on root content
      await storage.save({articleComment, fileComment});

      // Create a reply to a comment (nested comment) - create manually instead of using helper
      final nestedComment = PartialComment(
        content: 'Reply to the article comment',
        rootModel: article,
        parentModel: articleComment,
      ).dummySign(franzapPubkey);

      // Save nested comment separately
      await storage.save({nestedComment});

      // Test comment on article
      expect(articleComment.content, 'Comment on an article');
      expect(articleComment.rootModel.value, article);
      expect(articleComment.parentModel.value, article);
      expect(articleComment.rootKind, article.event.kind);
      expect(articleComment.parentKind, article.event.kind);
      expect(articleComment.rootAuthor.value, article.author.value);
      expect(articleComment.parentAuthor.value, article.author.value);

      // Test comment on file
      expect(fileComment.content, 'Comment on a file');
      expect(fileComment.rootModel.value, fileMetadata);
      expect(fileComment.parentModel.value, fileMetadata);
      expect(fileComment.rootKind, fileMetadata.event.kind);
      expect(fileComment.parentKind, fileMetadata.event.kind);
      expect(fileComment.rootAuthor.value, fileMetadata.author.value);
      expect(fileComment.parentAuthor.value, fileMetadata.author.value);

      // Test nested comment (reply to comment)
      expect(nestedComment.content, 'Reply to the article comment');
      expect(nestedComment.rootModel.value, article); // Same root as parent
      expect(nestedComment.parentModel.value,
          articleComment); // Parent is the first comment
      expect(nestedComment.rootKind, article.event.kind);
      expect(nestedComment.parentKind, 1111); // Parent kind is 1111 (Comment)
      expect(nestedComment.rootAuthor.value, article.author.value);
      expect(nestedComment.parentAuthor.value, articleComment.author.value);

      // Test relationship from article to comments
      final commentFromArticle = await container
          .read(storageNotifierProvider.notifier)
          .query(RequestFilter(kinds: {
            1111
          }, tags: {
            '#A': {article.id}
          }));

      expect(commentFromArticle, contains(articleComment));

      // Test relationship from article comment to its replies
      expect(articleComment.replies.toList(), contains(nestedComment));

      // Test external URI comments
      final externalComment = PartialComment(
        content: 'Comment on external content',
        externalRootUri: 'https://example.com/article/123',
        externalParentUri: 'https://example.com/article/123',
      ).dummySign(nielPubkey);

      await storage.save({externalComment});

      expect(
          externalComment.externalRootUri, 'https://example.com/article/123');
      expect(
          externalComment.externalParentUri, 'https://example.com/article/123');
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

final communityJson = '''
{
	"id": "26ac7e5ae58dc195f03272a0e5b66ba1d80806d31dc70e4c0cffa50a7594411c",
	"content": "",
	"created_at": 1744254000,
	"pubkey": "${Utils.hexFromNpub(nielPubkey)}",
	"kind": 10222,
	"tags": [
		[
			"name",
			"communikey"
		],
		[
			"r",
			"wss://communi.key"
		],
		[
			"description",
			"Some cool shit"
		],
		[
			"content",
			"Chat"
		],
		[
			"k",
			"9"
		],
    [
			"content",
			"Post"
		],
		[
			"k",
			"1"
		],
		[
			"k",
			"11"
		],
    [
			"fee",
			"10",
			"sat"
		],
    [
			"content",
			"Article"
		],
		[
			"k",
			"30023"
		],
		[
			"k",
			"30040"
		],
		[
			"fee",
			"21",
			"sat"
		],
		[
			"blossom",
			"https://cdn.communi.key"
		],
		[
			"tos",
			"https://tos"
		]
	],
	"sig": null
}
''';

final verbirichaJson = '''
{
        "content": "{\\"created_at\\":1712395725,\\"name\\":\\"verbiricha\\",\\"picture\\":\\"https://npub107jk7htfv243u0x5ynn43scq9wrxtaasmrwwa8lfu2ydwag6cx2quqncxg.blossom.band/3d84787d7284c879429eb0c8e6dcae0bf94cc50456d4046adf33cf040f8f5504.jpg\\",\\"about\\":\\"nostr flâneur\\",\\"lud16\\":\\"verbiricha@coinos.io\\",\\"nip05\\":\\"verbiricha@habla.news\\",\\"display_name\\":\\"verbiricha\\",\\"website\\":\\"https://chachi.chat\\",\\"banner\\":\\"https://npub107jk7htfv243u0x5ynn43scq9wrxtaasmrwwa8lfu2ydwag6cx2quqncxg.blossom.band/5caca44f65ee8e3f92737787e0aa453119a5564760104b244a5ed7f06f8322a7.jpg\\",\\"pubkey\\":\\"7fa56f5d6962ab1e3cd424e758c3002b8665f7b0d8dcee9fe9e288d7751ac194\\",\\"npub\\":\\"npub107jk7htfv243u0x5ynn43scq9wrxtaasmrwwa8lfu2ydwag6cx2quqncxg\\",\\"categories\\":[\\"Development & Engineering\\"],\\"displayName\\":\\"verbiricha\\"}",
        "created_at": 1743454587,
        "id": "81b04899af11bd0d7e4fbb5cee9349231fd247fb3d76e5944acf8cb6d58b2562",
        "kind": 0,
        "pubkey": "7fa56f5d6962ab1e3cd424e758c3002b8665f7b0d8dcee9fe9e288d7751ac194",
        "sig": "7fbba68e9821ed12bef2808e4b652e8f055fbbe6c1a8733a1c09f6fd52dc776c18edaad9e0213dfd4c512e55ca6367a2c0b24c5852fa1be2f0dac7393101d769",
        "tags": [
            [
                "alt",
                "User profile for verbiricha"
            ]
        ]
    }
''';

final franzapJson = '''
{
        "content": "{\\"about\\":\\"Building nostr:npub10r8xl2njyepcw2zwv3a6dyufj4e4ajx86hz6v4ehu4gnpupxxp7stjt2p8 - nostr:npub1kpt95rv4q3mcz8e4lamwtxq7men6jprf49l7asfac9lnv2gda0lqdknhmz - https://npub.world - The Business of Freedom Tech Podcast | BA 🇦🇷\\",\\"banner\\":\\"https://image.nostr.build/aa036e73c2ab116c24d4a31965c8796b0af2f78f2356d1d2fb61dae60547687b.jpg\\",\\"display_name\\":\\"franzap\\",\\"lud16\\":\\"zapstore@getalby.com\\",\\"name\\":\\"franzap\\",\\"nip05\\":\\"fran@zapstore.dev\\",\\"picture\\":\\"https://nostr.build/i/nostr.build_1732d9a6cd9614c6c4ac3b8f0ee4a8242e9da448e2aacb82e7681d9d0bc36568.jpg\\",\\"website\\":\\"https://zapstore.dev\\",\\"displayName\\":\\"franzap\\",\\"pubkey\\":\\"726a1e261cc6474674e8285e3951b3bb139be9a773d1acf49dc868db861a1c11\\",\\"npub\\":\\"npub1wf4pufsucer5va8g9p0rj5dnhvfeh6d8w0g6eayaep5dhps6rsgs43dgh9\\",\\"created_at\\":1732842936}",
        "created_at": 1740787196,
        "id": "3e37c0988907994d6c898f43111c8d2b856e2646fb9c849476c334b363848151",
        "kind": 0,
        "pubkey": "726a1e261cc6474674e8285e3951b3bb139be9a773d1acf49dc868db861a1c11",
        "sig": "935415d8175249d4838154643e018d8b7c98655c1b0e096e883e972f421ffed7f70b4a799c570f24d42c31d29cb175a0623fb11e99bad6aa29d130e71338a8b5",
        "tags": [
            [
                "alt",
                "User profile for franzap"
            ]
        ]
    }
''';

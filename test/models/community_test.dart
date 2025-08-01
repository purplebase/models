import 'dart:convert';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    ref = container.read(refProvider);
    storage =
        container.read(storageNotifierProvider.notifier)
            as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.cancel();
    await storage.clear();
    container.dispose();
  });

  group('Community', () {
    test('community', () async {
      // Create author profile first
      final authorProfile = PartialProfile(name: 'neil').dummySign(nielPubkey);
      await storage.save({authorProfile});

      final community = PartialCommunity(
        name: 'communikey',
        createdAt: DateTime.parse('2025-04-10'),
        description: 'Some cool shit',
        relayUrls: {'wss://communi.key'},
        blossomUrls: {'https://cdn.communi.key'},
        contentSections: {
          CommunityContentSection(content: 'Chat', kinds: {9}),
          CommunityContentSection(
            content: 'Post',
            kinds: {1, 11},
            feeInSats: 10,
          ),
          CommunityContentSection(
            content: 'Article',
            kinds: {30023, 30040},
            feeInSats: 21,
          ),
        },
        termsOfService: 'https://tos',
      ).dummySign(nielPubkey);

      await storage.save({community});
      expect(community.author.value!.pubkey, nielPubkey);

      final community2 = Community.fromMap(community.toMap(), ref);
      expect(community.toMap(), community2.toMap());
      expect(jsonDecode(communityJson), community2.toMap());

      final note = PartialNote('test').dummySign();
      final targetedPublication = PartialTargetedPublication(
        note,
        communities: {community},
      ).dummySign();
      await storage.save({community, note, targetedPublication});
      expect(targetedPublication.communities.toList(), [community]);
      expect(targetedPublication.model.value, note);
      expect(targetedPublication.event.identifier, hasLength(64));
    });

    test('community chatMessages relationship', () async {
      // Create a community
      final community = PartialCommunity(
        name: 'Test Community',
        relayUrls: {'wss://test.relay'},
        description: 'Test community for chat messages',
      ).dummySign(nielPubkey);

      // Create chat messages for the community
      final chatMessage1 = PartialChatMessage(
        'Hello community!',
        community: community,
      ).dummySign();

      final chatMessage2 = PartialChatMessage(
        'Another message',
        community: community,
      ).dummySign();

      // Save all to storage
      await storage.save({community, chatMessage1, chatMessage2});

      // Test that the chatMessages relationship works
      final chatMessages = community.chatMessages.toList();
      expect(chatMessages, hasLength(2));
      expect(
        chatMessages.map((m) => m.content),
        containsAll(['Hello community!', 'Another message']),
      );
    });
  });
}

final communityJson =
    '''
{
	"id": "26ac7e5ae58dc195f03272a0e5b66ba1d80806d31dc70e4c0cffa50a7594411c",
	"content": "",
	"created_at": 1744254000,
	"pubkey": "${nielPubkey.decodeShareable()}",
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

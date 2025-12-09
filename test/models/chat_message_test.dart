import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
    storage =
        container.read(storageNotifierProvider.notifier) as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.clear();
    container.dispose();
  });

  group('ChatMessage', () {
    test('basic chat message creation and parsing', () async {
      // Create a community first
      final community = PartialCommunity(
        name: 'Test Community',
        relayUrls: {'wss://test.relay.com'},
        description: 'A test community',
      ).dummySign(nielPubkey);

      // Create a basic chat message
      final chatMessage = PartialChatMessage(
        'Hello, community!',
        community: community,
      ).dummySign(verbirichaPubkey);

      await storage.save({community, chatMessage});

      expect(chatMessage.content, equals('Hello, community!'));
      expect(chatMessage.event.kind, equals(9));
      expect(chatMessage.community.value?.id, equals(community.id));
      expect(chatMessage.quotedMessage.value, isNull);
    });

    test('chat message with quoted message relationship', () async {
      // Create original message
      final originalMessage = PartialChatMessage(
        'Original message',
      ).dummySign(nielPubkey);

      // Create reply that quotes the original
      final quotingMessage = PartialChatMessage(
        'Replying to the original message',
        quotedMessage: originalMessage,
      ).dummySign(verbirichaPubkey);

      await storage.save({originalMessage, quotingMessage});

      // Test the relationship
      expect(
        quotingMessage.quotedMessage.value?.id,
        equals(originalMessage.id),
      );
      expect(
        quotingMessage.quotedMessage.value?.content,
        equals('Original message'),
      );
      expect(
        originalMessage.quotedMessage.value,
        isNull,
      ); // Original doesn't quote anything
    });

    test('real-world events from Zaplab community', () async {
      // Real-world event data from the user's examples
      final realWorldEvents = [
        {
          "kind": 9,
          "id":
              "bf3c3ac11d2944b4066e40f11951d5c6798b08c6192745f5dbc15da33454554b",
          "pubkey":
              "726a1e261cc6474674e8285e3951b3bb139be9a773d1acf49dc868db861a1c11",
          "created_at": 1733949164,
          "tags": [
            ["h", "_", "wss://zaplab.nostr1.com"],
            ["-"],
            ["previous", "0c2e486d", "cf8e724f", "9b2e5563"],
          ],
          "content": "Yo!",
          "sig":
              "2bb19d868abe23676df6114f019acfd2dea3f1b488a60bbec22e59f1b4f71b7b78451d10dc2484084db73fc5046cf34ba60db5e52a0dd5fee3e2b8f096e04936",
        },
        {
          "kind": 9,
          "id":
              "75eb630296793882c44e181de13b8cbf3ef40fe111ebf2c4bd5f05041ab5ba07",
          "pubkey":
              "a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be",
          "created_at": 1733933206,
          "tags": [
            ["h", "_", "wss://zaplab.nostr1.com"],
            ["-"],
            ["previous", "0c2e486d", "cf8e724f", "9b2e5563"],
            [
              "e",
              "00c9e5330199cd5b3aa2ead2bdf27b47c58158f3441b6b062be7998c95d2f439",
              "wss://niel.nostr1.com/",
              "mention",
            ],
            [
              "p",
              "a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be",
            ],
          ],
          "content":
              "This will be one of the most used building blocks. Basic, useful and unique to zaplab_design: nostr:nevent1qvzqqqqqqypzp22rfmsktmgpk2rtan7zwu00zuzax5maq5dnsu5g3xxvqr2u3pd7qyt8wumn8ghj7mnfv4kzumn0wd68yvfwvdhk6tcpz9mhxue69uhkummnw3ezuamfdejj7qpqqry72vcpn8x4kw4zatftmunmglzczk8ngsdkkp3tu7vce9wj7susqefljg",
          "sig":
              "9483e76ae144c06ec4a041adb54679a0cb5821f18663c7365c95eb3eed97244277b3acedbc9c5c182bd38639b6440b1d3844e1e9d672dfec486c7dcf1f8ee375",
        },
        {
          "kind": 9,
          "id":
              "0b6dbac93373da3ed2e4765582344a56e34584f3709a525f0e9ad31952706807",
          "pubkey":
              "a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be",
          "created_at": 1733479402,
          "tags": [
            ["h", "_", "wss://zaplab.nostr1.com"],
            ["-"],
            ["previous", "0c2e486d", "cf8e724f", "9b2e5563"],
          ],
          "content":
              "https://media.tenor.com/uBqT5bkx2KIAAAAx/welcome-cat.webp",
          "sig":
              "443dcd62b530546e7c3b8c4e5c286104d1951e518dfeccb3d2deff25edc797136dfdee6d99e93dd5cc3c5446fced55e783e571f8b5d4b8e222aef30d4262f1f1",
        },
      ];

      // Load the events into storage
      final models = <Model>[];
      final ref = container.read(refProvider);
      for (final eventData in realWorldEvents) {
        final model = ChatMessage.fromMap(eventData, ref);
        models.add(model);
      }
      await storage.save(models.toSet());

      // Test the parsed events
      expect(models.length, equals(3));

      final firstMessage = models[0] as ChatMessage;
      expect(firstMessage.content, equals('Yo!'));
      expect(firstMessage.event.containsTag('h'), isTrue);
      expect(firstMessage.event.getFirstTagValue('h'), equals('_'));
      // Community relationship will be null since "_" is not a valid community ID
      expect(firstMessage.community.value, isNull);

      final secondMessage = models[1] as ChatMessage;
      expect(
        secondMessage.content,
        contains('This will be one of the most used building blocks'),
      );
      expect(secondMessage.event.containsTag('e'), isTrue);
      expect(secondMessage.event.containsTag('p'), isTrue);
      // Community relationship will be null since "_" is not a valid community ID
      expect(secondMessage.community.value, isNull);

      final thirdMessage = models[2] as ChatMessage;
      expect(thirdMessage.content, contains('https://media.tenor.com/'));
      // Community relationship will be null since "_" is not a valid community ID
      expect(thirdMessage.community.value, isNull);
    });

    test('chat message without community or quoted message', () async {
      final chatMessage = PartialChatMessage(
        'Standalone message',
      ).dummySign(franzapPubkey);

      await storage.save({chatMessage});

      expect(chatMessage.content, equals('Standalone message'));
      expect(chatMessage.community.value, isNull);
      expect(chatMessage.quotedMessage.value, isNull);
    });

    test('chat message with invalid community reference', () async {
      // Create chat message with non-existent community ID
      final eventData = {
        "kind": 9,
        "id": "test123",
        "pubkey": nielPubkey,
        "created_at": DateTime.now().millisecondsSinceEpoch ~/ 1000,
        "tags": [
          ["h", "nonexistent-community-id"],
        ],
        "content": "Message in non-existent community",
        "sig": "testsig",
      };

      final ref = container.read(refProvider);
      final chatMessage = ChatMessage.fromMap(eventData, ref);
      await storage.save({chatMessage});

      expect(chatMessage.content, equals('Message in non-existent community'));
      expect(
        chatMessage.community.value,
        isNull,
      ); // Should be null since community ID format is invalid
    });

    test('chat message with invalid quoted message reference', () async {
      // Create chat message with non-existent quoted message ID (but valid format)
      final eventData = {
        "kind": 9,
        "id": "test456",
        "pubkey": verbirichaPubkey,
        "created_at": DateTime.now().millisecondsSinceEpoch ~/ 1000,
        "tags": [
          [
            "q",
            "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
          ],
        ],
        "content": "Quoting non-existent message",
        "sig": "testsig",
      };

      final ref = container.read(refProvider);
      final chatMessage = ChatMessage.fromMap(eventData, ref);
      await storage.save({chatMessage});

      expect(chatMessage.content, equals('Quoting non-existent message'));
      expect(
        chatMessage.quotedMessage.value,
        isNull,
      ); // Should be null since quoted message doesn't exist
    });

    test('partial chat message mixin', () {
      final partial = PartialChatMessage('Test content');

      expect(partial.content, equals('Test content'));

      partial.content = 'Updated content';
      expect(partial.content, equals('Updated content'));

      partial.content = null;
      expect(partial.content, isNull);
      expect(partial.event.content, equals(''));

      partial.content = '';
      expect(partial.content, isNull);
    });

    test('chat message relationships work correctly after fix', () async {
      // Create a community
      final community = PartialCommunity(
        name: 'Test Community',
        relayUrls: {'wss://test.relay.com'},
      ).dummySign(nielPubkey);

      // Create original message in community
      final originalMessage = PartialChatMessage(
        'Original message in community',
        community: community,
      ).dummySign(nielPubkey);

      // Create message that quotes the original
      final quotingMessage = PartialChatMessage(
        'I quote the original message',
        quotedMessage: originalMessage,
        community: community,
      ).dummySign(verbirichaPubkey);

      // Create another message in the same community (not quoting anything)
      final anotherMessage = PartialChatMessage(
        'Another message in same community',
        community: community,
      ).dummySign(franzapPubkey);

      await storage.save({
        community,
        originalMessage,
        quotingMessage,
        anotherMessage,
      });

      // Test quotedMessage relationship
      expect(
        quotingMessage.quotedMessage.value?.id,
        equals(originalMessage.id),
      );
      expect(originalMessage.quotedMessage.value, isNull);
      expect(anotherMessage.quotedMessage.value, isNull);

      // Test community relationships
      expect(originalMessage.community.value?.id, equals(community.id));
      expect(quotingMessage.community.value?.id, equals(community.id));
      expect(anotherMessage.community.value?.id, equals(community.id));

      // Test community's chatMessages relationship
      expect(community.chatMessages.toList().length, equals(3));
      expect(
        community.chatMessages.toList().map((m) => m.id).toSet(),
        containsAll([originalMessage.id, quotingMessage.id, anotherMessage.id]),
      );
    });

    test('edge case: chat message with empty content', () async {
      final chatMessage = PartialChatMessage('').dummySign(nielPubkey);
      await storage.save({chatMessage});

      expect(chatMessage.content, equals(''));
      expect(chatMessage.event.content, equals(''));
    });

    test('edge case: chat message with very long content', () async {
      final longContent = 'A' * 10000; // Very long message
      final chatMessage = PartialChatMessage(longContent).dummySign(nielPubkey);
      await storage.save({chatMessage});

      expect(chatMessage.content, equals(longContent));
      expect(chatMessage.content.length, equals(10000));
    });

    test('chat message inherits standard model relationships', () async {
      final chatMessage = PartialChatMessage(
        'Test message',
      ).dummySign(nielPubkey);
      await storage.save({chatMessage});

      // Should have inherited relationships from RegularModel
      expect(chatMessage.author, isNotNull);
      expect(chatMessage.reactions, isNotNull);
      expect(chatMessage.zaps, isNotNull);
      expect(chatMessage.genericReposts, isNotNull);
    });

    test('ensure kind 9 is used for chat messages', () {
      final chatMessage = PartialChatMessage('Test').dummySign(nielPubkey);
      expect(chatMessage.event.kind, equals(9));
    });
  });
}

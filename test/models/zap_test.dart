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

  group('Zap', () {
    test('creates zap from JSON and validates relationships', () async {
      final author = PartialProfile().dummySign(
        'd3f94b353542a632962062f3c914638d0deeba64af1f980d93907ee1b3e0d4f9',
      );
      final zap = Zap.fromMap(jsonDecode(zapJson), ref);
      final note = Note.fromMap(jsonDecode(zappedEventJson), ref);
      await storage.save({note, zap, author});

      // As config is keepSignatures=false, it should come back as null
      expect(zap.zappedModel.value!.event.signature, isNull);
      expect(zap.zappedModel.value, note);
      expect(zap.author.value, author);
    });

    test('calculates amount from bolt11 correctly', () {
      final zap = Zap.fromMap(jsonDecode(zapJson), ref);
      expect(zap.amount, equals(10)); // 100 nanosats = 10 sats
    });

    test('handles invalid bolt11 gracefully', () {
      final invalidZapJson = jsonDecode(zapJson) as Map<String, dynamic>;
      final tags = invalidZapJson['tags'] as List;
      // Replace bolt11 with invalid value
      for (int i = 0; i < tags.length; i++) {
        if (tags[i][0] == 'bolt11') {
          tags[i][1] = 'invalid_bolt11';
          break;
        }
      }

      final zap = Zap.fromMap(invalidZapJson, ref);
      expect(zap.amount, equals(0)); // Should return 0 for invalid bolt11
    });
  });

  group('ZapRequest', () {
    test('creates zap request from map', () {
      final zapRequest = ZapRequest.fromMap(jsonDecode(zapRequestJson), ref);
      expect(zapRequest.event.kind, equals(9734));
      expect(
        zapRequest.event.pubkey,
        equals(
          'd3f94b353542a632962062f3c914638d0deeba64af1f980d93907ee1b3e0d4f9',
        ),
      );
    });
  });

  group('PartialZapRequest with Mixin', () {
    test('creates partial zap request with default values', () {
      final partial = PartialZapRequest();
      expect(partial.comment, isNull);
      expect(partial.amount, isNull);
      expect(partial.relays, isEmpty);
      expect(partial.lnurl, isNull);
    });

    test('sets and gets comment property', () {
      final partial = PartialZapRequest();

      // Test setting comment
      partial.comment = 'Great post! ⚡';
      expect(partial.comment, equals('Great post! ⚡'));
      expect(partial.event.content, equals('Great post! ⚡'));

      // Test setting null comment
      partial.comment = null;
      expect(partial.comment, isNull);
      expect(partial.event.content, isEmpty);

      // Test setting empty comment
      partial.comment = '';
      expect(partial.comment, isNull);
      expect(partial.event.content, isEmpty);
    });

    test('sets and gets amount property', () {
      final partial = PartialZapRequest();

      // Test setting amount
      partial.amount = 21000;
      expect(partial.amount, equals(21000));
      expect(partial.event.getFirstTagValue('amount'), equals('21000'));

      // Test setting null amount
      partial.amount = null;
      expect(partial.amount, isNull);
      expect(partial.event.getFirstTagValue('amount'), isNull);

      // Test setting zero amount
      partial.amount = 0;
      expect(partial.amount, equals(0));
      expect(partial.event.getFirstTagValue('amount'), equals('0'));
    });

    test('sets and gets relays property', () {
      final partial = PartialZapRequest();

      // Test setting multiple relays
      final testRelays = [
        'wss://relay.damus.io',
        'wss://relay.primal.net',
        'wss://nos.lol',
      ];
      partial.relays = testRelays;
      expect(partial.relays, equals(testRelays));

      // Check that relays are stored as a single tag
      final relaysTag = partial.event.tags
          .where((tag) => tag[0] == 'relays')
          .first;
      expect(relaysTag.length, equals(4)); // 'relays' + 3 relay URLs
      expect(relaysTag.sublist(1), equals(testRelays));

      // Test setting empty relays
      partial.relays = [];
      expect(partial.relays, isEmpty);

      // Test setting single relay
      partial.relays = ['wss://single-relay.com'];
      expect(partial.relays, equals(['wss://single-relay.com']));
    });

    test('sets and gets lnurl property', () {
      final partial = PartialZapRequest();

      // Test setting lnurl
      const testLnurl =
          'lnurl1dp68gurn8ghj7um5v93kketj9ehx2amn9uh8wetvdskkkmn0wahz7mrww4excup0dajx2mrv92x9xp';
      partial.lnurl = testLnurl;
      expect(partial.lnurl, equals(testLnurl));
      expect(partial.event.getFirstTagValue('lnurl'), equals(testLnurl));

      // Test setting null lnurl
      partial.lnurl = null;
      expect(partial.lnurl, isNull);
      expect(partial.event.getFirstTagValue('lnurl'), isNull);

      // Test setting empty lnurl
      partial.lnurl = '';
      expect(partial.lnurl, isNull);
    });

    test('creates complete zap request with all properties', () {
      final partial = PartialZapRequest();

      // Set all properties
      partial.comment = 'Awesome content! ⚡⚡⚡';
      partial.amount = 42000;
      partial.relays = [
        'wss://relay.damus.io',
        'wss://relay.primal.net',
        'wss://nos.lol',
        'wss://relay.nostr.band',
      ];
      partial.lnurl =
          'lnurl1dp68gurn8ghj7um5v93kketj9ehx2amn9uh8wetvdskkkmn0wahz7mrww4excup0dajx2mrv92x9xp';

      // Verify all properties are set correctly
      expect(partial.comment, equals('Awesome content! ⚡⚡⚡'));
      expect(partial.amount, equals(42000));
      expect(partial.relays.length, equals(4));
      expect(
        partial.lnurl,
        equals(
          'lnurl1dp68gurn8ghj7um5v93kketj9ehx2amn9uh8wetvdskkkmn0wahz7mrww4excup0dajx2mrv92x9xp',
        ),
      );

      // Verify event structure
      expect(partial.event.content, equals('Awesome content! ⚡⚡⚡'));
      expect(partial.event.getFirstTagValue('amount'), equals('42000'));
      expect(
        partial.event.getFirstTagValue('lnurl'),
        contains('lnurl1dp68gurn8ghj7'),
      );

      final relaysTag = partial.event.tags
          .where((tag) => tag[0] == 'relays')
          .first;
      expect(relaysTag.contains('wss://relay.damus.io'), isTrue);
      expect(relaysTag.contains('wss://nos.lol'), isTrue);
    });

    test('handles edge cases for amount parsing', () {
      final partial = PartialZapRequest();

      // Manually set invalid amount tag
      partial.event.setTagValue('amount', 'invalid');
      expect(partial.amount, isNull);

      // Set negative amount
      partial.amount = -100;
      expect(partial.amount, equals(-100));
      expect(partial.event.getFirstTagValue('amount'), equals('-100'));

      // Set very large amount
      partial.amount = 999999999;
      expect(partial.amount, equals(999999999));
    });

    test('handles malformed relays tag', () {
      final partial = PartialZapRequest();

      // Manually add malformed relays tag (empty)
      partial.event.addTag('relays', []);
      expect(partial.relays, isEmpty);

      // Add relays tag with only the key
      partial.event.tags.clear();
      partial.event.tags.add(['relays']);
      expect(partial.relays, isEmpty);
    });

    test('creates from existing zap request map', () {
      final partial = PartialZapRequest.fromMap(jsonDecode(zapRequestJson));

      expect(partial.comment, equals('Onward 🫡'));
      expect(partial.relays.length, equals(8));
      expect(partial.relays, contains('wss://relay.primal.net'));
      expect(partial.relays, contains('wss://relay.damus.io'));
      expect(partial.relays, contains('wss://nos.lol'));

      // Verify we can modify the properties
      partial.comment = 'Modified comment';
      expect(partial.comment, equals('Modified comment'));
    });

    test('mixin works with inheritance', () {
      final partial = PartialZapRequest();

      // Verify mixin methods are available
      expect(partial.comment, isNull);
      expect(partial.amount, isNull);
      expect(partial.relays, isEmpty);
      expect(partial.lnurl, isNull);

      // Verify we can call base methods too
      expect(partial.event.kind, equals(9734));
      expect(partial.toMap(), isA<Map<String, dynamic>>());
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

final zapRequestJson = '''
{
  "id": "24783f6c0c60c72e444306fa5e3d71d4e3d01db8618daeccb5047b1714cd17b1",
  "pubkey": "d3f94b353542a632962062f3c914638d0deeba64af1f980d93907ee1b3e0d4f9",
  "created_at": 1743797156,
  "kind": 9734,
  "tags": [
    ["e", "be000cd2f9c727040bf8f776977ae13932206b183c7683f3577dbd34a0527265"],
    ["p", "83e818dfbeccea56b0f551576b3fd39a7a50e1d8159343500368fa085ccd964b"],
    ["relays", "wss://relay.primal.net", "wss://relay.damus.io", "wss://relay.nostr.band", "wss://relay.current.fyi", "wss://purplepag.es", "wss://nos.lol", "wss://offchain.pub", "wss://nostr.bitcoiner.social"]
  ],
  "content": "Onward 🫡",
  "sig": "516a51fb761b0dcd262069da90f25d7a767624c42ff688b70d8504e144964a8bb5da25fb9e429692cd1dd487487de961884086f7ae6da2443b6948604a6011ef"
}
''';

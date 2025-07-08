import 'dart:convert';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;
  late DummyStorageNotifier storage;

  setUpAll(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    ref = container.read(refProvider);
    storage = container.read(storageNotifierProvider.notifier)
        as DummyStorageNotifier;
  });

  group('Zap', () {
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

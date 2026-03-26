import 'dart:convert';
import 'dart:math';

import 'package:faker/faker.dart';
import 'package:riverpod/riverpod.dart';

import 'package:models/models.dart';

/// Provider for test data generator
final testDataGeneratorProvider = Provider<TestDataGenerator>((ref) {
  return TestDataGenerator(ref);
});

/// Utility class for generating test data
class TestDataGenerator {
  final Ref ref;
  final Random _random = Random();

  TestDataGenerator(this.ref);

  /// Seeds the storage with a realistic dataset during initialization
  Future<Set<Model>> generateSeedData() async {
    final seededModels = <Model>{};

    // Generate 20-50 profiles
    final profiles = List.generate(
      20 + _random.nextInt(30),
      (i) => generateProfile(),
    );
    seededModels.addAll(profiles);
    final signer = DummySigner(ref, pubkey: profiles.first.pubkey);
    await signer.signIn();

    // Generate contact lists for some profiles
    for (int i = 0; i < profiles.length ~/ 3; i++) {
      final profile = profiles[i];
      final follows = profiles
          .where((p) => p.pubkey != profile.pubkey)
          .take(_random.nextInt(15))
          .toSet();
      final contactList = generateModel(
        kind: 3,
        pubkey: profile.pubkey,
        pTags: follows.map((p) => p.pubkey).toSet(),
      );
      if (contactList != null) seededModels.add(contactList);
    }

    // Generate 200-500 notes with realistic timestamps (spread over last 7 days)
    final noteCount = 200 + _random.nextInt(300);
    for (int i = 0; i < noteCount; i++) {
      final author = profiles[_random.nextInt(profiles.length)];
      final createdAt = DateTime.now().subtract(
        Duration(
          minutes: _random.nextInt(7 * 24 * 60), // Random time in last 7 days
        ),
      );
      final note = generateModel(
        kind: 1,
        pubkey: author.pubkey,
        createdAt: createdAt,
      );
      if (note != null) {
        seededModels.add(note);

        // Add some reactions to notes (10% chance)
        if (_random.nextDouble() < 0.1) {
          final reactions = List.generate(_random.nextInt(20), (j) {
            final reactor = profiles[_random.nextInt(profiles.length)];
            return generateModel(
              kind: 7,
              parentId: note.event.id,
              pubkey: reactor.pubkey,
            );
          }).whereType<Model>();
          seededModels.addAll(reactions);
        }

        // Add some zaps to notes (5% chance)
        if (_random.nextDouble() < 0.05) {
          final zaps = List.generate(_random.nextInt(5), (j) {
            final zapper = profiles[_random.nextInt(profiles.length)];
            return generateModel(
              kind: 9735,
              parentId: note.event.id,
              pubkey: zapper.pubkey,
            );
          }).whereType<Model>();
          seededModels.addAll(zaps);
        }
      }
    }

    return seededModels;
  }

  /// Generates a fake profile
  Profile generateProfile([String? pubkey]) {
    return PartialProfile(
      name: faker.person.name(),
      nip05: faker.internet.freeEmail(),
      pictureUrl: faker.internet.httpsUrl(),
    ).dummySign(pubkey);
  }

  /// Generates a fake model, supported kinds: 0, 1, 3, 7, 9735
  Model? generateModel({
    required int kind,
    String? parentId,
    String? pubkey,
    DateTime? createdAt,
    Set<String> pTags = const {},
  }) {
    pubkey ??= Utils.generateRandomHex64();
    return switch (kind) {
      0 => generateProfile(),
      1 => PartialNote(
        faker.lorem.sentence(),
        createdAt: createdAt,
      ).dummySign(pubkey),
      3 => PartialContactList(followPubkeys: pTags).dummySign(pubkey),
      7 =>
        parentId == null
            ? null
            : (PartialReaction()..event.addTag('e', [parentId])).dummySign(
                pubkey,
              ),
      9 => PartialChatMessage(faker.lorem.sentence()).dummySign(pubkey),
      9735 =>
        parentId != null
            ? Zap.fromMap(
                _sampleZap(zapperPubkey: pubkey, eventId: parentId),
                ref,
              )
            : null,
      _ => null,
    };
  }

  /// Generates a new model that would match the given filter
  Model? generateModelMatchingFilter(RequestFilter filter) {
    // Pick a kind from the filter, or use a common kind
    final kinds = filter.kinds.isNotEmpty ? filter.kinds : {1, 7, 9735};
    final kind = kinds.elementAt(_random.nextInt(kinds.length));

    // Pick an author from the filter, or generate random
    String? pubkey;
    if (filter.authors.isNotEmpty) {
      pubkey = filter.authors.elementAt(_random.nextInt(filter.authors.length));
    }

    return generateModel(kind: kind, pubkey: pubkey, createdAt: DateTime.now());
  }

  /// Sample zap data for testing
  Map<String, dynamic> _sampleZap({
    required String zapperPubkey,
    required String eventId,
  }) => jsonDecode('''
{
        "content": "✨",
        "created_at": ${DateTime.now().millisecondsSinceEpoch ~/ 1000},
        "id": "${Utils.generateRandomHex64()}",
        "kind": 9735,
        "pubkey": "79f00d3f5a19ec806189fcab03c1be4ff81d18ee4f653c88fac41fe8f04a9f5f67e4a3c1cc",
        "tags": [
            [
                "p",
                "20651ab8c2fb1febca56b80deba14630af452bdce64fe8f04a9f5f67e4a3c1cc"
            ],
            [
                "e",
                "$eventId"
            ],
            [
                "P",
                "$zapperPubkey"
            ],
            [
                "bolt11",
                "lnbc210n1pnl48jjxqrrsspqqsqqdpvta04q5jff4q5ch6ffe2y25jwg9x97j2w2e85js69ta0s29da748s3yt4frxt8t4z62h3l3g2dlu6tynlefsjffdhn45dr84h3my9h4t7ety4s7awnlkl89p26tkq4jkc3z54ufjmwg96ddjtk7spnl55zu"
            ],
            [
                "preimage",
                "986393670e035a9c131353a796fc2a0fb9f09e6112ca3c89a4f00f9dd2356afb"
            ],
            [
                "description",
                                 "{\\"id\\":\\"50dd637e30455a6dd6e1c9159c58b2cba31c75df29a5806162b813b3d93fe13d\\",\\"sig\\":\\"b86c1e09139e0367d9ed985beb14995efb3025eb68c8a56045ce2a2a35639d8f4187acae78c022532801fb068cf3560dcab12497f6d2a9376978c9bde35b15cd\\",\\"pubkey\\":\\"97f848adcc4c6276685fe48426de5614887c8a51ada0468cec71fba938272911\\",\\"created_at\\":1744474327,\\"kind\\":9734,\\"tags\\":[[\\"relays\\",\\"wss://relay.primal.net\\"],[\\"amount\\",\\"21000\\"],[\\"p\\",\\"20651ab8c2fb1febca56b80deba14630af452bdce64fe8f04a9f5f67e4a3c1cc\\"],[\\"e\\",\\"7abbce7aa0c5cd430efd627bbe5b5908de48db5cec5742f694befe38b34bce9f\\"]],\\"content\\":\\"✨\\"}"
            ]
        ]
    }
''');
}

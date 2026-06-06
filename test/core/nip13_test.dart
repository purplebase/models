import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

const _pubkey =
    'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be';

final class _MutatingDummySigner extends DummySigner {
  _MutatingDummySigner(Ref ref) : super(ref, pubkey: _pubkey);

  @override
  Future<List<E>> sign<E extends Model<dynamic>>(
    List<PartialModel<Model<dynamic>>> partialModels,
  ) {
    for (final partialModel in partialModels) {
      partialModel.event.addTagValue('mutated-after-mining', 'true');
    }
    return super.sign<E>(partialModels);
  }
}

void main() {
  late ProviderContainer container;
  late DummySigner signer;

  setUp(() async {
    container = await createTestContainer();
    signer = DummySigner(container.ref, pubkey: _pubkey);
    await signer.signIn();
  });

  tearDown(() => container.tearDown());

  group('Nip13 difficulty', () {
    test('counts official NIP-13 examples', () {
      expect(
        Nip13.difficultyForId(
          '000000000e9d97a1ab09fc381030b346cdd7a142ad57e6df0b46dc9bef6c7e2d',
        ),
        36,
      );
      expect(Nip13.difficultyForId('002f'.padRight(64, '0')), 10);
      expect(Nip13.difficultyForId('0'.padRight(64, '0')), 256);
      expect(Nip13.difficultyForId('1'.padRight(64, '0')), 3);
      expect(Nip13.difficultyForId('7'.padRight(64, '0')), 1);
      expect(Nip13.difficultyForId('8'.padRight(64, '0')), 0);
    });

    test('rejects malformed event IDs', () {
      expect(
        () => Nip13.difficultyForId('002f'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Nip13.difficultyForId('g'.padRight(64, 'g')),
        throwsA(isA<FormatException>()),
      );
    });

    test('validates actual and committed difficulty', () {
      const id =
          '000006d8c378af1779d2feebc7603a125d99eca0ccf1085959b307f64e5dd358';

      expect(
        Nip13.isValidProof(
          id: id,
          tags: const [
            ['nonce', '776797', '20'],
          ],
          minimumDifficulty: 20,
        ),
        isTrue,
      );
      expect(
        Nip13.isValidProof(id: id, tags: const [], minimumDifficulty: 20),
        isFalse,
      );
      expect(
        Nip13.isValidProof(
          id: id,
          tags: const [],
          minimumDifficulty: 20,
          requireCommitment: false,
        ),
        isTrue,
      );
      expect(
        Nip13.isValidProof(
          id: id,
          tags: const [
            ['nonce', '776797', '19'],
          ],
          minimumDifficulty: 20,
        ),
        isFalse,
      );
      expect(
        Nip13.isValidProof(
          id: id,
          tags: const [
            ['nonce', '776797', '22'],
          ],
          minimumDifficulty: 20,
        ),
        isFalse,
      );
      expect(
        Nip13.isValidProof(
          id: id,
          tags: const [
            ['nonce', '776797', 'invalid'],
          ],
          minimumDifficulty: 20,
        ),
        isFalse,
      );
    });
  });

  group('Nip13 mining', () {
    test('mines and commits proof while preserving timestamp', () async {
      final partial = PartialNote('mine me');
      final createdAt = DateTime.utc(2020, 1, 2, 3, 4, 5);
      partial.event
        ..createdAt = createdAt
        ..tags.addAll([
          ['nonce', 'stale', '1'],
          ['t', 'nostr'],
          ['nonce', 'duplicate', '2'],
        ]);

      final result = await Nip13.mine(
        partial.event,
        pubkey: _pubkey,
        options: ProofOfWorkOptions(
          difficulty: 8,
          maxAttempts: 100000,
          timeout: const Duration(seconds: 5),
          startNonce: 0,
        ),
      );

      expect(result.difficulty, greaterThanOrEqualTo(8));
      expect(result.id, Utils.getEventId(partial.event, _pubkey));
      expect(partial.event.createdAt, createdAt);
      expect(partial.event.getTagSet('nonce'), hasLength(1));
      expect(partial.event.getFirstTag('nonce'), [
        'nonce',
        result.nonce.toString(),
        '8',
      ]);
      expect(partial.event.getFirstTagValue('t'), 'nostr');
    });

    test('restores tags when attempt budget is exhausted', () async {
      final partial = PartialNote('cannot reasonably reach 256 bits');
      partial.event.tags = [
        ['t', 'original'],
        ['nonce', 'old', '4'],
      ];
      final originalTags = [
        for (final tag in partial.event.tags) List<String>.of(tag),
      ];

      await expectLater(
        Nip13.mine(
          partial.event,
          pubkey: _pubkey,
          options: ProofOfWorkOptions(
            difficulty: 256,
            maxAttempts: 1,
            timeout: const Duration(seconds: 1),
          ),
        ),
        throwsA(
          isA<ProofOfWorkLimitExceeded>()
              .having((error) => error.attempts, 'attempts', 1)
              .having(
                (error) => error.targetDifficulty,
                'targetDifficulty',
                256,
              ),
        ),
      );

      expect(partial.event.tags, originalTags);
    });

    test('batch mining failure restores earlier successful partials', () async {
      final createdAt = DateTime.utc(2020, 1, 2, 3, 4, 5);

      PartialNote candidate({required bool shouldMeetTarget}) {
        for (var i = 0; ; i++) {
          final partial = PartialNote('candidate $i', createdAt: createdAt);
          partial.event.setTag('nonce', ['0', '4']);
          final meetsTarget =
              Nip13.difficultyForId(Utils.getEventId(partial.event, _pubkey)) >=
              4;
          partial.event.removeTag('nonce');
          if (meetsTarget == shouldMeetTarget) return partial;
        }
      }

      final first = candidate(shouldMeetTarget: true);
      final second = candidate(shouldMeetTarget: false);
      final partials = <PartialModel<Model>>[first, second];

      await expectLater(
        SignerExtension<Note>(partials).signWith(
          signer,
          proofOfWork: ProofOfWorkOptions(
            difficulty: 4,
            maxAttempts: 1,
            timeout: const Duration(seconds: 1),
          ),
        ),
        throwsA(isA<ProofOfWorkLimitExceeded>()),
      );

      expect(first.event.containsTag('nonce'), isFalse);
      expect(second.event.containsTag('nonce'), isFalse);
    });
  });

  group('Nip13 signing', () {
    test('signWith mines the final signed event', () async {
      final signed = await PartialNote('signed proof').signWith(
        signer,
        proofOfWork: ProofOfWorkOptions(
          difficulty: 8,
          maxAttempts: 100000,
          timeout: const Duration(seconds: 5),
        ),
      );

      expect(Nip13.isValid(signed.event, minimumDifficulty: 8), isTrue);
    });

    test('encrypted content is prepared before mining', () async {
      final signed =
          await PartialDirectMessage(
            content: 'secret proof',
            receiver: _pubkey,
          ).signWith(
            signer,
            proofOfWork: ProofOfWorkOptions(
              difficulty: 8,
              maxAttempts: 100000,
              timeout: const Duration(seconds: 5),
            ),
          );

      expect(signed.content, contains('dummy_nip44_encrypted'));
      expect(Nip13.isValid(signed.event, minimumDifficulty: 8), isTrue);
    });

    test('iterable signWith prepares and mines every partial', () async {
      final partials = <PartialModel<Model>>[
        PartialDirectMessage(content: 'first', receiver: _pubkey),
        PartialDirectMessage(content: 'second', receiver: _pubkey),
      ];

      final signed = await SignerExtension<DirectMessage>(partials).signWith(
        signer,
        proofOfWork: ProofOfWorkOptions(
          difficulty: 8,
          maxAttempts: 100000,
          timeout: const Duration(seconds: 5),
        ),
      );

      expect(signed, hasLength(2));
      for (final message in signed) {
        expect(message.content, contains('dummy_nip44_encrypted'));
        expect(Nip13.isValid(message.event, minimumDifficulty: 8), isTrue);
      }
    });

    test('rejects a signer that changes the mined event', () async {
      final mutatingSigner = _MutatingDummySigner(container.ref);
      await mutatingSigner.signIn();

      await expectLater(
        PartialNote('mutated proof').signWith(
          mutatingSigner,
          proofOfWork: ProofOfWorkOptions(
            difficulty: 4,
            maxAttempts: 10000,
            timeout: const Duration(seconds: 5),
          ),
        ),
        throwsA(isA<ProofOfWorkInvalidated>()),
      );
    });
  });
}

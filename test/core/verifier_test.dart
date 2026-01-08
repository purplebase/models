import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;

  setUpAll(() async {
    container = ProviderContainer();
    ref = container.read(refProvider);
  });

  tearDownAll(() {
    container.dispose();
  });

  group('Verifier', () {
    late Verifier verifier;

    setUp(() {
      verifier = container.read(verifierProvider);
    });

    test('verifierProvider returns DartVerifier instance', () {
      final verifier = container.read(verifierProvider);
      expect(verifier, isA<DartVerifier>());
    });

    test('verify returns true for valid signed event', () async {
      // Initialize storage first
      final config = StorageConfiguration();
      await container.read(initializationProvider(config).future);

      // Create a real signed event using the signer
      const privateKey =
          'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8';
      final signer = Bip340PrivateKeySigner(privateKey, ref);
      await signer.signIn();

      final partialNote = PartialNote('Test note for verification');
      final signedNote = await partialNote.signWith(signer);

      // Verify the signed event
      final result = verifier.verify(signedNote.toMap());
      expect(result, isTrue);
    });

    test('verify returns false for invalid signature', () {
      final invalidEvent = {
        'id': 'test_event_id',
        'pubkey': 'test_pubkey',
        'sig': 'invalid_signature',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 1,
        'tags': [],
        'content': 'Test content',
      };

      final result = verifier.verify(invalidEvent);
      expect(result, isFalse);
    });

    test('verify returns false for missing signature', () {
      final eventWithoutSig = {
        'id': 'test_event_id',
        'pubkey': 'test_pubkey',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 1,
        'tags': [],
        'content': 'Test content',
      };

      final result = verifier.verify(eventWithoutSig);
      expect(result, isFalse);
    });
  });
}

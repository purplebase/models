import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CryptographicIdentityProof', () {
    const certificateHash =
        'e0382ce13f09f4a4f969b95b351ede3b52f1d8946896db0bba85b9f255ae9693';

    test('maps NIP-C1 proof fields', () {
      final expiry = DateTime.now().add(const Duration(days: 365));
      final proof = PartialCryptographicIdentityProof(
        certificateHash: certificateHash,
        signature: 'signature-base64',
        expiry: expiry,
      ).dummySign(franzapPubkey);

      expect(proof.event.kind, 30509);
      expect(proof.certificateHash, certificateHash);
      expect(proof.signature, 'signature-base64');
      expect(
        proof.expiry!.millisecondsSinceEpoch ~/ 1000,
        expiry.millisecondsSinceEpoch ~/ 1000,
      );
      expect(proof.isActive, isTrue);
      expect(proof.id, '30509:$franzapPubkey:$certificateHash');
      expect(
        CryptographicIdentityProof.fromMap(proof.toMap(), container.ref),
        proof,
      );
    });

    test('treats expired or revoked proofs as inactive', () {
      final expired = PartialCryptographicIdentityProof(
        certificateHash: certificateHash,
        signature: 'signature-base64',
        expiry: DateTime.now().subtract(const Duration(days: 1)),
      ).dummySign(franzapPubkey);

      final revokedPartial = PartialCryptographicIdentityProof(
        certificateHash: certificateHash,
        signature: 'signature-base64',
        expiry: DateTime.now().add(const Duration(days: 365)),
      )..revoke('key-retired');
      final revoked = revokedPartial.dummySign(franzapPubkey);

      expect(expired.isActive, isFalse);
      expect(revoked.isActive, isFalse);
      expect(revoked.revokedReason, 'key-retired');
    });
  });
}

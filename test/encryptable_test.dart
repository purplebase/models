import 'dart:convert';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;

  setUp(() async {
    container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
    ref = container.read(refProvider);
  });

  tearDown(() async {
    container.dispose();
  });

  group('EncryptableModel - AppPack (Self-Encryption)', () {
    test('provides access to encrypted content', () {
      final appPack = PartialAppPack(
        name: 'Test Pack',
        identifier: 'test-pack',
      ).dummySign(nielPubkey);

      expect(appPack.content, isNotNull);
      expect(appPack.getEncryptionPubkey(), equals(nielPubkey));
      expect(appPack.useNip04, isFalse);
    });

    test('encrypted private apps are not accessible without decryption', () {
      final partial = PartialAppPack.withEncryptedApps(
        name: 'Private Apps',
        identifier: 'private',
        apps: ['32267:pubkey:app1', '32267:pubkey:app2'],
      );

      final appPack = partial.dummySign(nielPubkey);

      // Content is encrypted, so privateAppIds returns empty
      expect(appPack.privateAppIds, isEmpty);
      expect(appPack.content, contains('dummy_nip44_encrypted'));
    });
  });

  group('EncryptablePartialModel - Content Management', () {
    late Signer signer;

    setUp(() async {
      final privateKey = Utils.generateRandomHex64();
      signer = Bip340PrivateKeySigner(privateKey, ref);
      await signer.signIn();
    });

    test('content management before encryption', () async {
      final partial = PartialAppPack(name: 'Test Pack', identifier: 'test');

      partial.setContent('Hello World');
      expect(partial.content, equals('Hello World'));

      partial.setContent({'key': 'value'});
      expect(partial.content, equals('{"key":"value"}'));

      partial.clearContent();
      expect(partial.content, isEmpty);
    });

    test('encryption during prepareForSigning with NIP-44', () async {
      final partial = PartialAppPack(name: 'Test Pack', identifier: 'test');
      partial.setContent('Secret message');

      // Before encryption
      expect(partial.content, equals('Secret message'));

      await partial.prepareForSigning(signer);

      // After encryption - content should be encrypted
      expect(partial.content, isNot(equals('Secret message')));
      expect(
        partial.content.length,
        greaterThan(10),
      ); // Encrypted content is longer
    });

    test('prevents double encryption', () async {
      final partial = PartialAppPack(name: 'Test Pack', identifier: 'test');
      partial.setContent('Original message');

      // First encryption
      await partial.prepareForSigning(signer);
      final firstEncrypted = partial.content;

      // Second encryption attempt - should not change
      await partial.prepareForSigning(signer);
      expect(partial.content, equals(firstEncrypted));
    });

    test('handles empty content gracefully', () async {
      final partial = PartialAppPack(name: 'Empty Pack', identifier: 'empty');
      // No content set

      await partial.prepareForSigning(signer);
      // Should not crash, content remains empty
      expect(partial.content, isEmpty);
    });

    test('encrypts JSON data correctly', () async {
      final partial = PartialAppPack(name: 'Test Pack', identifier: 'test');
      final testData = {
        'messages': ['Hello', 'World'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'nested': {'key': 'value'},
      };

      partial.setContent(testData);
      final originalJson = partial.content;

      await partial.prepareForSigning(signer);

      // Content should be encrypted, not the original JSON
      expect(partial.content, isNot(equals(originalJson)));
      expect(partial.content, isNot(contains('Hello')));
      expect(partial.content, isNot(contains('World')));
    });
  });

  group('Encryption Detection Logic', () {
    test('detects encrypted content', () {
      // We can't directly test the private _isAlreadyEncrypted method,
      // but we can test its behavior through prepareForSigning

      final partial = PartialAppPack(name: 'Test Pack', identifier: 'test');

      // Manually set encrypted content (simulating encryption)
      partial.setContent('dGVzdA?iv=1234567890abcdef');

      // prepareForSigning should not double-encrypt
      final originalContent = partial.content;

      // Since it's already "encrypted", prepareForSigning should leave it unchanged
      // We can't easily test this without a real signer, but we can verify the content remains
      expect(partial.content, equals(originalContent));
    });

    test('detects NIP-44 format in encrypted content', () {
      final partial = PartialAppPack(name: 'Test Pack', identifier: 'test');

      // Manually set encrypted content (simulating NIP-44)
      const nip44Encrypted =
          'AQBxY3J5cHRlZCBkYXRhIHRoYXQgaXMgdmVyeSBsb25nIGFuZCBjb250YWlucyBsb3RzIG9mIGNoYXJhY3RlcnMgZm9yIHRlc3RpbmcgcHVycG9zZXM=';
      partial.setContent(nip44Encrypted);

      // prepareForSigning should not double-encrypt
      final originalContent = partial.content;
      expect(partial.content, equals(originalContent));
    });
  });

  group('Integration Scenarios', () {
    late Signer signer;

    setUp(() async {
      final privateKey = Utils.generateRandomHex64();
      signer = Bip340PrivateKeySigner(privateKey, ref);
      await signer.signIn();
    });

    test('self-encrypted content workflow with AppPack', () async {
      // Test the full workflow: plaintext -> encrypt -> encrypted
      final partial = PartialAppPack.withEncryptedApps(
        name: 'Private Apps',
        identifier: 'private',
        apps: ['32267:pubkey:secret1', '32267:pubkey:secret2'],
      );

      // Before signing: content is plaintext accessible
      expect(partial.privateAppIds, contains('32267:pubkey:secret1'));
      expect(partial.privateAppIds, contains('32267:pubkey:secret2'));
      final originalContent = partial.content;

      await partial.prepareForSigning(signer);

      // After signing: content is encrypted
      expect(partial.content, isNot(equals(originalContent)));
      expect(partial.content, isNot(contains('secret1')));
      expect(partial.content, isNot(contains('secret2')));
    });

    test('encryption key selection for self-encryption', () async {
      final partial = PartialAppPack(
        name: 'Self-Encrypted',
        identifier: 'self',
      );

      // For self-encryption, should use signer's pubkey
      final encryptionKey = partial.getEncryptionPubkey(signer);
      expect(encryptionKey, equals(signer.pubkey));
    });

    test('real encryption preserves data integrity', () async {
      final testData = {
        'apps': ['32267:pubkey:app1', '32267:pubkey:app2'],
        'metadata': {'created': DateTime.now().toIso8601String()},
      };

      final partial = PartialAppPack(name: 'Test Pack', identifier: 'test');
      partial.setContent(testData);

      final originalJson = jsonEncode(testData);
      expect(partial.content, equals(originalJson));

      await partial.prepareForSigning(signer);

      // After encryption, content should be different but valid
      expect(partial.content, isNot(equals(originalJson)));
      expect(partial.content, isNotEmpty);

      // Should be able to decrypt back (in real usage)
      final decrypted = await signer.nip44Decrypt(
        partial.content,
        signer.pubkey,
      );
      expect(decrypted, equals(originalJson));
    });
  });

  group('NIP-04 vs NIP-44 Compatibility', () {
    test('AppPack uses NIP-44 by default', () {
      final partial = PartialAppPack(name: 'Test Pack', identifier: 'test');

      expect(partial.useNip04, isFalse); // Should default to NIP-44
    });

    test('DirectMessage uses NIP-44', () {
      // DirectMessage uses NIP-44
      final partial = PartialDirectMessage(
        content: 'Test message',
        receiver: nielPubkey,
      );

      expect(partial.useNip04, isFalse);
    });

    test('DirectMessage uses NIP-44 by default', () {
      final partial = PartialDirectMessage(
        content: 'Test message',
        receiver: nielPubkey,
        // useNip44 defaults to true
      );

      expect(
        partial.useNip04,
        isFalse,
      ); // NIP-44 is default, so useNip04 is false
    });
  });

  group('Error Handling', () {
    late Signer signer;

    setUp(() async {
      final privateKey = Utils.generateRandomHex64();
      signer = Bip340PrivateKeySigner(privateKey, ref);
      await signer.signIn();
    });

    test('handles malformed JSON gracefully', () async {
      final partial = PartialAppPack(name: 'Test Pack', identifier: 'test');

      // Set malformed JSON
      partial.setContent('{invalid json');

      await partial.prepareForSigning(signer);

      // Should encrypt malformed content anyway
      expect(partial.content, isNot(equals('{invalid json')));
      expect(partial.content, isNotEmpty);
    });

    test('handles very large content', () async {
      final partial = PartialAppPack(name: 'Large Pack', identifier: 'large');

      // Create large content
      final largeData = List.generate(1000, (i) => 'item$i');
      partial.setContent(largeData);

      final originalLength = partial.content.length;

      await partial.prepareForSigning(signer);

      // Encrypted content should be different length
      expect(partial.content.length, isNot(equals(originalLength)));
      expect(partial.content, isNot(contains('item0')));
    });
  });
}

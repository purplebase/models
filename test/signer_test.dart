import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;

  setUpAll(() async {
    container = ProviderContainer();
    ref = container.read(refProvider);
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
  });

  group('Signer', () {
    group('Bip340PrivateKeySigner', () {
      late Bip340PrivateKeySigner signer;
      const privateKey =
          'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8';

      setUp(() {
        signer = Bip340PrivateKeySigner(privateKey, ref);
      });

      test('initialization', () async {
        expect(signer.isInitialized, isFalse);
        expect(() => signer.pubkey, throwsA(isA<TypeError>()));

        await signer.initialize();

        expect(signer.isInitialized, isTrue);
        expect(signer.pubkey, isNotNull);
        expect(signer.pubkey, hasLength(64));
      });

      test('signing models', () async {
        await signer.initialize();

        final partialNote = PartialNote('Test note content');
        final signedModels = await signer.sign<Note>([partialNote]);

        expect(signedModels, hasLength(1));
        final signedNote = signedModels.first;
        expect(signedNote.event.content, 'Test note content');
        expect(signedNote.event.pubkey, signer.pubkey);
        expect(signedNote.event.id, isNotNull);
        expect(signedNote.event.signature, isNotNull);
      });

      test('signing multiple models', () async {
        await signer.initialize();

        final partialModels = [
          PartialNote('Note 1'),
          PartialNote('Note 2'),
          PartialNote('Note 3'),
        ];

        final signedModels = await signer.sign<Note>(partialModels);

        expect(signedModels, hasLength(3));
        for (int i = 0; i < signedModels.length; i++) {
          expect(signedModels[i].event.content, 'Note ${i + 1}');
          expect(signedModels[i].event.pubkey, signer.pubkey);
        }
      });

      test('signing DirectMessage with encryption works correctly', () async {
        await signer.initialize();
        final recipientNpub = Utils.npubFromHex(nielPubkey);
        const message = 'Hello, this is a secret message!';

        final partialDM = PartialDirectMessage(
          content: message,
          receiver: recipientNpub,
          useNip44: true,
        );

        final signedDM = await partialDM.signWith(signer);

        // Should be encrypted with NIP-44
        expect(signedDM.encryptedContent, isNotEmpty);
        expect(signedDM.encryptedContent,
            isNot(message)); // Should be encrypted, not plain
        expect(signedDM.isEncrypted, isTrue);

        // Should be able to decrypt back to original message
        final decrypted = await signedDM.decryptContent();
        expect(decrypted, message);
      });

      test('NIP-04 encryption methods work with real implementation', () async {
        await signer.initialize();
        const recipientPubkey =
            'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be';
        const message = 'Hello, secret message!';

        final encrypted = await signer.nip04Encrypt(message, recipientPubkey);
        expect(encrypted, isNotEmpty);
        expect(encrypted, contains('?iv='));

        final decrypted = await signer.nip04Decrypt(encrypted, recipientPubkey);
        expect(decrypted, message);
      });

      test('NIP-44 encryption methods work with real implementation', () async {
        await signer.initialize();
        const recipientPubkey =
            'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be';
        const message = 'Hello, secret message!';

        final encrypted = await signer.nip44Encrypt(message, recipientPubkey);
        expect(encrypted, isNotEmpty);
        expect(
            encrypted,
            startsWith(
                'A')); // NIP-44 encrypted messages start with 'A' in base64

        final decrypted = await signer.nip44Decrypt(encrypted, recipientPubkey);
        expect(decrypted, message);
      });

      test('encryption methods require initialization', () async {
        const recipientPubkey =
            'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be';
        const message = 'Hello, secret message!';

        expect(
          () async => await signer.nip04Encrypt(message, recipientPubkey),
          throwsA(isA<StateError>()),
        );

        expect(
          () async =>
              await signer.nip04Decrypt('encrypted_content', recipientPubkey),
          throwsA(isA<StateError>()),
        );

        expect(
          () async => await signer.nip44Encrypt(message, recipientPubkey),
          throwsA(isA<StateError>()),
        );

        expect(
          () async =>
              await signer.nip44Decrypt('encrypted_content', recipientPubkey),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('DummySigner', () {
      late DummySigner signer;

      setUp(() {
        signer = DummySigner(ref);
      });

      test('initialization', () async {
        expect(signer.isInitialized, isFalse);
        expect(() => signer.pubkey, throwsA(isA<TypeError>()));

        await signer.initialize();

        expect(signer.isInitialized, isTrue);
        expect(signer.pubkey, isNotNull);
        expect(signer.pubkey, hasLength(64));
      });

      test('initialization with custom pubkey', () async {
        const customPubkey =
            'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be';
        final customSigner = DummySigner(ref, pubkey: customPubkey);

        await customSigner.initialize();

        expect(customSigner.pubkey, customPubkey);
      });

      test('NIP-04 dummy encryption/decryption', () async {
        await signer.initialize();
        const recipientPubkey =
            'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be';
        const message = 'Hello, secret message!';

        final encrypted = await signer.nip04Encrypt(message, recipientPubkey);
        expect(encrypted, contains('dummy_nip04_encrypted'));
        expect(encrypted, contains(message.hashCode.toString()));
        expect(encrypted, contains(recipientPubkey));

        final decrypted = await signer.nip04Decrypt(encrypted, recipientPubkey);
        expect(decrypted, contains('dummy_nip04_decrypted'));
        expect(decrypted, contains(encrypted.hashCode.toString()));
        expect(decrypted, contains(recipientPubkey));
      });

      test('NIP-44 dummy encryption/decryption', () async {
        await signer.initialize();
        const recipientPubkey =
            'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be';
        const message = 'Hello, secret message!';

        final encrypted = await signer.nip44Encrypt(message, recipientPubkey);
        expect(encrypted, contains('dummy_nip44_encrypted'));
        expect(encrypted, contains(message.hashCode.toString()));
        expect(encrypted, contains(recipientPubkey));

        final decrypted = await signer.nip44Decrypt(encrypted, recipientPubkey);
        expect(decrypted, contains('dummy_nip44_decrypted'));
        expect(decrypted, contains(encrypted.hashCode.toString()));
        expect(decrypted, contains(recipientPubkey));
      });
    });

    group('Signer Providers', () {
      test('signer registration and retrieval', () async {
        const pubkey =
            'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be';
        final signer = DummySigner(ref, pubkey: pubkey);
        await signer.initialize();

        // Check that signer is registered
        final retrievedSigner = container.read(Signer.signerProvider(pubkey));
        expect(retrievedSigner, signer);

        // Check signed in pubkeys
        final signedInPubkeys = container.read(Signer.signedInPubkeysProvider);
        expect(signedInPubkeys, contains(pubkey));

        // Check active signer
        final activeSigner = container.read(Signer.activeSignerProvider);
        expect(activeSigner, signer);
      });
    });
  });

  group('DirectMessage Encryption Integration', () {
    late Bip340PrivateKeySigner signer;
    const privateKey =
        'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8';
    final recipientHex = nielPubkey;
    final recipientNpub = Utils.npubFromHex(nielPubkey);

    setUp(() async {
      signer = Bip340PrivateKeySigner(privateKey, ref);
      await signer.initialize();
    });

    test('PartialDirectMessage creation with encryption', () {
      const message = 'Hello, this is a secret message!';

      final partialDM = PartialDirectMessage(
        content: message,
        receiver: recipientNpub,
        useNip44: true,
      );

      expect(partialDM.plainContent, message);
      expect(partialDM.content, message); // Not encrypted yet
      expect(partialDM.receiver, recipientHex);
    });

    test('PartialDirectMessage with pre-encrypted content', () {
      const encryptedContent = 'dummy_encrypted_content';

      final partialDM = PartialDirectMessage.encrypted(
        encryptedContent: encryptedContent,
        receiver: recipientNpub,
      );

      expect(partialDM.plainContent, isNull);
      expect(partialDM.content, encryptedContent);
      expect(partialDM.receiver, recipientHex);
    });

    test('automatic encryption during signing works correctly', () async {
      const message = 'Hello, this is a secret message!';

      final partialDM = PartialDirectMessage(
        content: message,
        receiver: recipientNpub,
        useNip44: true,
      );

      final signedDM = await partialDM.signWith(signer);

      // Should be encrypted with NIP-44
      expect(signedDM.encryptedContent, isNotEmpty);
      expect(signedDM.encryptedContent,
          isNot(message)); // Should be encrypted, not plain
      expect(signedDM.isEncrypted, isTrue);

      // Should be able to decrypt back to original message
      final decrypted = await signedDM.decryptContent();
      expect(decrypted, message);
    });

    test('isEncrypted detection', () {
      // Test NIP-44 detection (starts with 'Ag')
      final nip44DM = PartialDirectMessage.encrypted(
        encryptedContent: 'AgSomeEncryptedContent==',
        receiver: recipientNpub,
      ).dummySign();

      expect(nip44DM.isEncrypted, isTrue);

      // Test NIP-04 detection (contains '?')
      final nip04DM = PartialDirectMessage.encrypted(
        encryptedContent: 'encrypted?content=here',
        receiver: recipientNpub,
      ).dummySign();

      expect(nip04DM.isEncrypted, isTrue);

      // Test plain text
      final plainDM = PartialDirectMessage.encrypted(
        encryptedContent: 'Hello world',
        receiver: recipientNpub,
      ).dummySign();

      expect(plainDM.isEncrypted, isFalse);
    });
  });

  group('Signable Mixin', () {
    late Bip340PrivateKeySigner signer;
    const privateKey =
        'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8';

    setUp(() async {
      signer = Bip340PrivateKeySigner(privateKey, ref);
      await signer.initialize();
    });

    test('signWith method for regular models', () async {
      final partialNote = PartialNote('Test note content');
      final signedNote = await partialNote.signWith(signer);

      expect(signedNote.event.content, 'Test note content');
      expect(signedNote.event.pubkey, signer.pubkey);
      expect(signedNote.event.signature, isNotNull);
    });

    test('dummySign method for regular models', () {
      final partialNote = PartialNote('Test note content');
      final signedNote = partialNote.dummySign();

      expect(signedNote.event.content, 'Test note content');
      expect(signedNote.event.pubkey, isNotNull);
    });

    test('signWith handles DirectMessage encryption correctly', () async {
      const message = 'Secret message';
      final recipientNpub = Utils.npubFromHex(nielPubkey);

      final partialDM = PartialDirectMessage(
        content: message,
        receiver: recipientNpub,
        useNip44: true,
      );

      final signedDM = await partialDM.signWith(signer);

      // Should be encrypted with NIP-44
      expect(signedDM.encryptedContent, isNotEmpty);
      expect(signedDM.encryptedContent,
          isNot(message)); // Should be encrypted, not plain
      expect(signedDM.isEncrypted, isTrue);

      // Should be able to decrypt back to original message
      final decrypted = await signedDM.decryptContent();
      expect(decrypted, message);
    });

    test('dummySign handles DirectMessage encryption', () {
      const message = 'Secret message';
      final recipientNpub = Utils.npubFromHex(nielPubkey);

      final partialDM = PartialDirectMessage(
        content: message,
        receiver: recipientNpub,
        useNip44: false,
      );

      final signedDM = partialDM.dummySign();

      // Should be encrypted with dummy encryption
      expect(signedDM.encryptedContent, contains('dummy_nip04_encrypted'));
      expect(signedDM.encryptedContent, contains(message.hashCode.toString()));
    });
  });
}

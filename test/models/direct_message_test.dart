import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
    ref = container.read(refProvider);
    storage =
        container.read(storageNotifierProvider.notifier) as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.clear();
    container.dispose();
  });

  group('DirectMessage', () {
    test('basic direct message creation and properties', () {
      final dm = PartialDirectMessage(
        content: 'Hello, Alice!',
        receiver: nielPubkey,
      ).dummySign(franzapPubkey);

      expect(dm.event.kind, 4);
      expect(dm.receiver, startsWith('npub1'));
      expect(dm.message, contains('dummy_nip44_encrypted')); // Encrypted content
      expect(dm.getEncryptionPubkey(), equals(nielPubkey)); // Encrypts to recipient
      expect(dm.useNip04, isFalse); // Uses NIP-44 by default
    });

    test('uses NIP-44 by default', () {
      final dm = PartialDirectMessage(
        content: 'Hello with NIP-44!',
        receiver: nielPubkey,
      );

      expect(dm.useNip04, isFalse); // NIP-44 is the default
    });

    test('handles npub receiver encoding', () {
      final receiverNpub = Utils.encodeShareableFromString(nielPubkey, type: 'npub');
      final dm = PartialDirectMessage(
        content: 'Hello!',
        receiver: receiverNpub, // Pass npub instead of hex
      ).dummySign(franzapPubkey);

      expect(dm.receiver, equals(receiverNpub));
      expect(dm.event.getFirstTagValue('p'), equals(nielPubkey)); // Stored as hex
    });

    test('handles invalid receiver gracefully', () {
      // decodeShareable doesn't validate, it just tries to decode
      final dm = PartialDirectMessage(
        content: 'Hello!',
        receiver: 'invalid-receiver', // This gets stored as-is
      ).dummySign(franzapPubkey);

      // The invalid receiver gets stored in the p tag
      expect(dm.event.getFirstTagValue('p'), equals('invalid-receiver'));
    });

    test('encryption key is recipient pubkey', () async {
      final dm = PartialDirectMessage(
        content: 'Secret message',
        receiver: nielPubkey,
      );

      final privateKey = Utils.generateRandomHex64();
      final signer = Bip340PrivateKeySigner(privateKey, ref);
      await signer.signIn();

      expect(dm.getEncryptionPubkey(signer), equals(nielPubkey));
    });

    test('content encryption during signing', () {
      final partial = PartialDirectMessage(
        content: 'Plain text message',
        receiver: nielPubkey,
      );

      // Before signing: content is plaintext
      expect(partial.content, equals('Plain text message'));

      final signed = partial.dummySign(franzapPubkey);

      // After signing: content is encrypted
      expect(signed.content, isNot(equals('Plain text message')));
      expect(signed.content, contains('dummy_nip44_encrypted'));
    });
  });

  group('DirectMessage Encryption Behavior', () {
    late Signer signer;

    setUp(() async {
      final privateKey = Utils.generateRandomHex64();
      signer = Bip340PrivateKeySigner(privateKey, ref);
      await signer.signIn();
    });

    test('real encryption with NIP-44', () async {
      final partial = PartialDirectMessage(
        content: 'Real encrypted message',
        receiver: nielPubkey,
      );

      final originalContent = partial.content;
      await partial.prepareForSigning(signer);

      // Content should be encrypted with NIP-44 format
      expect(partial.content, isNot(equals(originalContent)));
      expect(partial.content, isNot(contains('?iv='))); // NIP-44 format (no ?iv=)
    });

    test('real encryption with NIP-44', () async {
      final partial = PartialDirectMessage(
        content: 'Real NIP-44 encrypted message',
        receiver: nielPubkey,
      );

      final originalContent = partial.content;
      await partial.prepareForSigning(signer);

      // Content should be encrypted with NIP-44 format
      expect(partial.content, isNot(equals(originalContent)));
      expect(partial.content, isNot(contains('?iv='))); // Not NIP-04 format
      expect(partial.content.length, greaterThan(originalContent.length));
    });

    test('prevents double encryption', () async {
      final partial = PartialDirectMessage(
        content: 'Message to encrypt once',
        receiver: nielPubkey,
      );

      await partial.prepareForSigning(signer);
      final firstEncrypted = partial.content;

      // Try to encrypt again
      await partial.prepareForSigning(signer);

      // Should remain the same (no double encryption)
      expect(partial.content, equals(firstEncrypted));
    });

    test('encryption preserves data integrity', () async {
      final message = 'This is a test message with special chars: !@#\$%^&*()';
      final partial = PartialDirectMessage(
        content: message,
        receiver: nielPubkey,
      );

      await partial.prepareForSigning(signer);

      // Should be able to decrypt back to original
      final decrypted = await signer.nip44Decrypt(partial.content, nielPubkey);
      expect(decrypted, equals(message));
    });
  });

  group('DirectMessage Storage and Retrieval', () {
    test('saves and loads encrypted direct messages', () async {
      final dm = PartialDirectMessage(
        content: 'Stored encrypted message',
        receiver: nielPubkey,
      ).dummySign(franzapPubkey);

      await storage.save({dm});

      final retrieved = await storage.query(Request<DirectMessage>.fromIds({dm.id}));
      expect(retrieved.length, 1);

      final loaded = retrieved.first;
      expect(loaded.id, equals(dm.id));
      expect(loaded.receiver, equals(dm.receiver));
      expect(loaded.message, equals(dm.message)); // Still encrypted
      expect(loaded.content, contains('dummy_nip44_encrypted'));
    });

    test('multiple direct messages with different recipients', () async {
      final dm1 = PartialDirectMessage(
        content: 'Message to Alice',
        receiver: nielPubkey,
      ).dummySign(franzapPubkey);

      final dm2 = PartialDirectMessage(
        content: 'Message to Bob',
        receiver: verbirichaPubkey,
      ).dummySign(franzapPubkey);

      await storage.save({dm1, dm2});

      // Query all DMs from sender
      final allFromSender = await storage.query(
        RequestFilter<DirectMessage>(authors: {franzapPubkey}).toRequest(),
      );

      expect(allFromSender.length, 2);
      final messages = allFromSender.map((dm) => dm.content).toSet();
      // Check that both messages are encrypted
      expect(messages.length, 2);
      expect(messages.every((msg) => msg.contains('dummy_nip44_encrypted')), isTrue);
    });
  });

  group('DirectMessage Relationships', () {
    test('author relationship', () async {
      final profile = PartialProfile(name: 'Alice').dummySign(franzapPubkey);
      final dm = PartialDirectMessage(
        content: 'Hello!',
        receiver: nielPubkey,
      ).dummySign(franzapPubkey);

      await storage.save({profile, dm});

      // Reload to ensure relationships are established
      final reloadedDM = await storage.query(Request<DirectMessage>.fromIds({dm.id}));
      expect(reloadedDM.length, 1);
      expect(reloadedDM.first.author.value, equals(profile));
    });

    test('can query direct messages by author', () async {
      final profile = PartialProfile(name: 'Alice').dummySign(franzapPubkey);

      final dm1 = PartialDirectMessage(
        content: 'First message',
        receiver: nielPubkey,
      ).dummySign(franzapPubkey);

      final dm2 = PartialDirectMessage(
        content: 'Second message',
        receiver: verbirichaPubkey,
      ).dummySign(franzapPubkey);

      await storage.save({profile, dm1, dm2});

      // Query DMs by author
      final authorDMs = await storage.query(
        RequestFilter<DirectMessage>(authors: {franzapPubkey}).toRequest(),
      );

      expect(authorDMs.length, 2);
      // Check that both messages are encrypted
      expect(authorDMs.length, 2);
      expect(authorDMs.every((dm) => dm.content.contains('dummy_nip44_encrypted')), isTrue);
    });
  });

  group('DirectMessage Event Structure', () {
    test('has correct event kind and tags', () {
      final dm = PartialDirectMessage(
        content: 'Test message',
        receiver: nielPubkey,
      ).dummySign(franzapPubkey);

      expect(dm.event.kind, 4);
      expect(dm.event.getFirstTagValue('p'), equals(nielPubkey));
      expect(dm.event.tags.length, 1); // Only p tag for recipient
    });

    test('includes additional tags when provided', () {
      final partial = PartialDirectMessage(
        content: 'Message with tags',
        receiver: nielPubkey,
      );

      // Add additional tags
      partial.event.addTagValue('subject', 'Important');
      partial.event.addTagValue('reply', 'previous-event-id');

      final dm = partial.dummySign(franzapPubkey);

      expect(dm.event.getFirstTagValue('p'), equals(nielPubkey));
      expect(dm.event.getFirstTagValue('subject'), equals('Important'));
      expect(dm.event.getFirstTagValue('reply'), equals('previous-event-id'));
    });

    test('shareable ID encoding', () {
      final dm = PartialDirectMessage(
        content: 'Shareable test',
        receiver: nielPubkey,
      ).dummySign(franzapPubkey);

      final shareableId = dm.event.shareableId;
      expect(shareableId, startsWith('nevent1'));
    });
  });

  group('DirectMessage Error Cases', () {
    test('throws on missing recipient during encryption', () async {
      final partial = PartialDirectMessage(
        content: 'Message',
        receiver: nielPubkey,
      );

      // Manually remove the p tag to simulate error
      partial.event.tags.clear();

      final signer = Bip340PrivateKeySigner('a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be', ref);
      await signer.signIn();

      expect(
        () => partial.getEncryptionPubkey(signer),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('DirectMessage must have a receiver'),
        )),
      );
    });

    test('handles empty content', () {
      final dm = PartialDirectMessage(
        content: '',
        receiver: nielPubkey,
      ).dummySign(franzapPubkey);

      // Empty content doesn't get encrypted
      expect(dm.content, equals(''));
      expect(dm.message, equals(''));
    });

    test('handles very long content', () {
      final longMessage = 'This is a very long message with lots of content that should be encrypted properly when using NIP-44 encryption methods in the DirectMessage system.' * 50; // Long message
      final dm = PartialDirectMessage(
        content: longMessage,
        receiver: nielPubkey,
      ).dummySign(franzapPubkey);

      // Content should be encrypted (contains dummy marker)
      expect(dm.content, contains('dummy'));
      expect(dm.content, contains('encrypted'));
      expect(dm.content.length, greaterThan(0));
    });

    test('handles special characters in content', () {
      const specialMessage = 'Special chars: éñüñ 中文 🔥 🚀\n\t\r';
      final dm = PartialDirectMessage(
        content: specialMessage,
        receiver: nielPubkey,
      ).dummySign(franzapPubkey);

      expect(dm.content, isNot(equals(specialMessage)));
      expect(dm.content, contains('dummy'));
      expect(dm.content, contains('encrypted'));
    });
  });

  group('DirectMessage NIP Compatibility', () {
    test('NIP-44 encryption format', () {
      final dm = PartialDirectMessage(
        content: 'NIP-44 test',
        receiver: nielPubkey,
      ).dummySign(franzapPubkey);

      // Dummy encryption happened
      expect(dm.content, isNot(equals('NIP-44 test')));
      expect(dm.content, contains('dummy'));
    });

    test('DirectMessage uses NIP-44 by default', () {
      final dm = PartialDirectMessage(
        content: 'Modern message',
        receiver: nielPubkey,
      );

      expect(dm.useNip04, isFalse); // NIP-44 is the default
    });
  });
}

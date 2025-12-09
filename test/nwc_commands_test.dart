import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;
  late String testNwcConnectionString;
  late StorageNotifier storage;
  late Signer signer;

  setUp(() async {
    container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
    ref = container.read(refProvider);
    storage =
        container.read(storageNotifierProvider.notifier) as DummyStorageNotifier;

    // Create and sign in a test signer
    final privateKey = Utils.generateRandomHex64();
    signer = Bip340PrivateKeySigner(privateKey, ref);
    await signer.signIn();

    // Create a test NWC connection string
    final secret = Utils.generateRandomHex64();
    testNwcConnectionString =
        'nostr+walletconnect://$franzapPubkey?relay=wss://localhost:7777&secret=$secret';
  });

  tearDown(() async {
    await signer.clearNWCString();
    await storage.clear();
    container.dispose();
  });

  group('Signer NWC API', () {
    test('sets and gets NWC connection string', () async {
      // Initially should be null
      final initial = await signer.getNWCString();
      expect(initial, isNull);

      // Set the connection string
      await signer.setNWCString(testNwcConnectionString);

      // Should now return the connection string
      final retrieved = await signer.getNWCString();
      expect(retrieved, equals(testNwcConnectionString));
    });

    test('clears NWC connection string', () async {
      // Set a connection string
      await signer.setNWCString(testNwcConnectionString);

      // Verify it's set
      final beforeClear = await signer.getNWCString();
      expect(beforeClear, equals(testNwcConnectionString));

      // Clear it
      await signer.clearNWCString();

      // Should now be null
      final afterClear = await signer.getNWCString();
      expect(afterClear, isNull);
    });

    test('NWC string is encrypted in storage', () async {
      await signer.setNWCString(testNwcConnectionString);

      // Check that the stored CustomData is encrypted (not plain text)
      final customDataList = await storage.query(
        RequestFilter<CustomData>(
          authors: {signer.pubkey},
          tags: {
            '#d': {Signer.kNwcConnectionString},
          },
        ).toRequest(),
        source: LocalSource(),
      );

      expect(customDataList.length, equals(1));
      final customData = customDataList.first;

      // The content should be encrypted, not the original string
      expect(customData.content, isNot(equals(testNwcConnectionString)));
      expect(customData.content, isNotEmpty);
    });

    test('validates NWC URI format when setting', () async {
      // Test valid URI
      await signer.setNWCString(testNwcConnectionString);
      final retrieved = await signer.getNWCString();
      expect(retrieved, equals(testNwcConnectionString));

      // Test that we can store any string - validation happens during parsing
      const invalidUri = 'invalid-uri-format';
      await signer.setNWCString(invalidUri);

      final retrievedInvalid = await signer.getNWCString();
      expect(retrievedInvalid, equals(invalidUri));
    });

    test('handles NWC URI with optional parameters', () async {
      final secret = Utils.generateRandomHex64();
      final uriWithLud16 =
          'nostr+walletconnect://$franzapPubkey?relay=wss://localhost:7777&secret=$secret&lud16=test@example.com';

      await signer.setNWCString(uriWithLud16);
      final retrieved = await signer.getNWCString();
      expect(retrieved, equals(uriWithLud16));
    });
  });

  group('NWC Commands', () {
    test('PayInvoiceCommand creates correct structure', () {
      const invoice = 'lnbc1000n1pjqwdqcpp5...';
      final command = PayInvoiceCommand(invoice: invoice);

      expect(command.method, equals(NwcInfo.payInvoice));
      expect(command.params['invoice'], equals(invoice));

      final request = PartialNwcRequest(
        walletPubkey: franzapPubkey,
        method: command.method,
        params: command.params,
        expiration: DateTime.now().add(Duration(minutes: 5)),
      );

      expect(request.event.kind, equals(23194));
      expect(request.event.getFirstTagValue('p'), equals(franzapPubkey));
      expect(request.event.content, isNotEmpty);
    });
  });

  group('ZapRequest.pay()', () {
    test('throws when no NWC connection configured', () async {
      // Create a zap request without setting up NWC
      final zapRequest = PartialZapRequest();
      zapRequest.amount = 1000;
      zapRequest.linkProfileByPubkey(franzapPubkey);

      final signedZapRequest = await zapRequest.signWith(signer);

      await expectLater(
        () => signedZapRequest.pay(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No NWC connection configured'),
          ),
        ),
      );
    });

    test('throws when signer not found', () async {
      // Create a dummy signer but don't register it in the provider
      final isolatedSigner = DummySigner(ref);
      await isolatedSigner.signIn(
        registerSigner: false,
      ); // Sign in but don't register

      final zapRequest = PartialZapRequest();
      zapRequest.amount = 1000;
      zapRequest.linkProfileByPubkey(franzapPubkey);

      final signedZapRequest = await zapRequest.signWith(isolatedSigner);

      await expectLater(
        () => signedZapRequest.pay(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No signer found for pubkey'),
          ),
        ),
      );
    });
  });
}

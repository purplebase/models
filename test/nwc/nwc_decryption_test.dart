import 'dart:convert';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

/// Tests for NWC response decryption functionality.
/// 
/// NWC (Nostr Wallet Connect) uses NIP-04 encryption for communication
/// between clients and wallet services. The response from a wallet service
/// is encrypted to the client's pubkey and must be decrypted before parsing.
void main() {
  late ProviderContainer container;
  late Ref ref;
  late Signer clientSigner;
  late Signer walletSigner;

  setUp(() async {
    container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
    ref = container.read(refProvider);

    // Create client and wallet signers with fixed keys for reproducible tests
    final clientPrivateKey = Utils.generateRandomHex64();
    final walletPrivateKey = Utils.generateRandomHex64();

    clientSigner = Bip340PrivateKeySigner(clientPrivateKey, ref);
    walletSigner = Bip340PrivateKeySigner(walletPrivateKey, ref);

    await clientSigner.signIn(registerSigner: false);
    await walletSigner.signIn(registerSigner: false);
  });

  tearDown(() async {
    await container.read(storageNotifierProvider.notifier).clear();
    container.dispose();
  });

  group('NWC Response Decryption', () {
    test('encrypted response can be created and decrypted', () async {
      // Create a pay_invoice success response
      final partialResponse = PartialNwcResponse.payInvoiceSuccess(
        clientPubkey: clientSigner.pubkey,
        preimage: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        feesPaid: 10,
        requestEventId: '0' * 64,
      );

      // Sign the response with the wallet signer - this encrypts the content
      final signedResponse = await partialResponse.signWith(walletSigner);

      // Verify the content is encrypted (should be base64-like)
      expect(signedResponse.content, isNotEmpty);
      expect(signedResponse.content.length, greaterThan(50));
      
      // Verify content is NOT plaintext JSON (encryption happened)
      expect(() => jsonDecode(signedResponse.content), throwsFormatException);

      // Now decrypt the response content using client's signer
      final decryptedStr = await clientSigner.nip04Decrypt(
        signedResponse.content,
        walletSigner.pubkey,
      );

      // Parse the decrypted content
      final decrypted = jsonDecode(decryptedStr) as Map<String, dynamic>;
      
      // Verify the decrypted content has expected structure
      expect(decrypted['result_type'], equals('pay_invoice'));
      expect(decrypted['result'], isNotNull);
      expect(decrypted['result']['preimage'], isNotEmpty);
      expect(decrypted['error'], isNull);
    });

    test('encrypted request can be created and decrypted', () async {
      // Create a pay_invoice request
      final partialRequest = PartialNwcRequest.payInvoice(
        walletPubkey: walletSigner.pubkey,
        invoice: 'lnbc10n1pjtest',
        amount: 1000,
      );

      // Sign the request with the client signer - this encrypts the content
      final signedRequest = await partialRequest.signWith(clientSigner);

      // Verify the content is encrypted (should be base64-like)
      expect(signedRequest.content, isNotEmpty);
      expect(signedRequest.content.length, greaterThan(50));
      
      // Verify content is NOT plaintext JSON (encryption happened)
      expect(() => jsonDecode(signedRequest.content), throwsFormatException);

      // Now decrypt the request content using wallet's signer
      final decryptedStr = await walletSigner.nip04Decrypt(
        signedRequest.content,
        clientSigner.pubkey,
      );

      // Parse the decrypted content
      final decrypted = jsonDecode(decryptedStr) as Map<String, dynamic>;
      
      // Verify the decrypted content has expected structure
      expect(decrypted['method'], equals('pay_invoice'));
      expect(decrypted['params'], isNotNull);
      expect(decrypted['params']['invoice'], equals('lnbc10n1pjtest'));
    });

    test('encrypted error response can be decrypted', () async {
      final error = NwcError(
        code: NwcError.insufficientBalance,
        message: 'Wallet balance too low',
      );

      final partialResponse = PartialNwcResponse.error(
        clientPubkey: clientSigner.pubkey,
        resultType: 'pay_invoice',
        error: error,
        requestEventId: '0' * 64,
      );

      // Sign encrypts the content
      final signedResponse = await partialResponse.signWith(walletSigner);

      // Decrypt
      final decryptedStr = await clientSigner.nip04Decrypt(
        signedResponse.content,
        walletSigner.pubkey,
      );

      final decrypted = jsonDecode(decryptedStr) as Map<String, dynamic>;
      
      expect(decrypted['result_type'], equals('pay_invoice'));
      expect(decrypted['error'], isNotNull);
      expect(decrypted['error']['code'], equals('INSUFFICIENT_BALANCE'));
      expect(decrypted['error']['message'], equals('Wallet balance too low'));
      expect(decrypted['result'], isNull);
    });

    test('get_balance response roundtrip encryption', () async {
      final partialResponse = PartialNwcResponse.getBalanceSuccess(
        clientPubkey: clientSigner.pubkey,
        balance: 50000,
        requestEventId: '1' * 64,
      );

      final signedResponse = await partialResponse.signWith(walletSigner);
      
      final decryptedStr = await clientSigner.nip04Decrypt(
        signedResponse.content,
        walletSigner.pubkey,
      );

      final decrypted = jsonDecode(decryptedStr) as Map<String, dynamic>;
      
      expect(decrypted['result_type'], equals('get_balance'));
      expect(decrypted['result']['balance'], equals(50000));
    });

    test('NwcNotification roundtrip encryption', () async {
      final partialNotification = PartialNwcNotification.paymentReceived(
        clientPubkey: clientSigner.pubkey,
        invoice: 'lnbc1000n1pjtest',
        preimage: 'abc' * 21 + 'a', // 64 chars
        paymentHash: 'def' * 21 + 'd', // 64 chars
        amount: 1000,
        settledAtTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      final signedNotification = await partialNotification.signWith(walletSigner);

      // Content should be encrypted
      expect(() => jsonDecode(signedNotification.content), throwsFormatException);

      // Decrypt
      final decryptedStr = await clientSigner.nip04Decrypt(
        signedNotification.content,
        walletSigner.pubkey,
      );

      final decrypted = jsonDecode(decryptedStr) as Map<String, dynamic>;
      
      expect(decrypted['notification_type'], equals('payment_received'));
      expect(decrypted['notification'], isNotNull);
      expect(decrypted['notification']['amount'], equals(1000));
    });
  });

  group('NWC Connection Parsing', () {
    test('parses valid NWC URI', () {
      const uri = 'nostr+walletconnect://72bdbc57bdd6dfc4e62685051de8041d148c3c68fe42bf301f71aa6cf53e52fb'
          '?relay=wss%3A%2F%2Frelay.coinos.io'
          '&secret=e51b61224cf4bac1a42deff61afe7eea22cce7d5ece719edabf182466a0a763e'
          '&lud16=franzap@coinos.io';

      final connection = NwcConnection.fromUri(uri);

      expect(
        connection.walletPubkey,
        equals('72bdbc57bdd6dfc4e62685051de8041d148c3c68fe42bf301f71aa6cf53e52fb'),
      );
      expect(connection.relay, equals('wss://relay.coinos.io'));
      expect(
        connection.secret,
        equals('e51b61224cf4bac1a42deff61afe7eea22cce7d5ece719edabf182466a0a763e'),
      );
      expect(connection.lud16, equals('franzap@coinos.io'));
      expect(connection.isExpired, isFalse);
    });

    test('derives correct client pubkey from secret', () {
      const uri = 'nostr+walletconnect://72bdbc57bdd6dfc4e62685051de8041d148c3c68fe42bf301f71aa6cf53e52fb'
          '?relay=wss%3A%2F%2Frelay.coinos.io'
          '&secret=e51b61224cf4bac1a42deff61afe7eea22cce7d5ece719edabf182466a0a763e';

      final connection = NwcConnection.fromUri(uri);

      // The client pubkey should be derived from the secret
      expect(connection.clientPubkey.length, equals(64));
      expect(
        connection.clientPubkey,
        equals(Utils.derivePublicKey(connection.secret)),
      );
    });

    test('throws on invalid URI format', () {
      expect(
        () => NwcConnection.fromUri('invalid-uri'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on missing secret', () {
      const uri = 'nostr+walletconnect://72bdbc57bdd6dfc4e62685051de8041d148c3c68fe42bf301f71aa6cf53e52fb'
          '?relay=wss%3A%2F%2Frelay.example.com';

      expect(
        () => NwcConnection.fromUri(uri),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on missing relay', () {
      const uri = 'nostr+walletconnect://72bdbc57bdd6dfc4e62685051de8041d148c3c68fe42bf301f71aa6cf53e52fb'
          '?secret=e51b61224cf4bac1a42deff61afe7eea22cce7d5ece719edabf182466a0a763e';

      expect(
        () => NwcConnection.fromUri(uri),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}


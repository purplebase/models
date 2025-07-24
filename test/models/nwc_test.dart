import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;

  setUpAll(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    ref = container.read(refProvider);
  });

  group('NwcInfo', () {
    test('creates and parses supported methods', () {
      final partialInfo = PartialNwcInfo(
        supportedMethods: ['pay_invoice', 'get_balance', 'make_invoice'],
        supportedNotifications: ['payment_received', 'payment_sent'],
      );

      final info = partialInfo.dummySign(nielPubkey);

      expect(info.event.kind, 13194);
      expect(info.supportedMethods, [
        'pay_invoice',
        'get_balance',
        'make_invoice',
      ]);
      expect(info.supportedNotifications, ['payment_received', 'payment_sent']);
      expect(info.supportsMethod('pay_invoice'), isTrue);
      expect(info.supportsMethod('unknown_method'), isFalse);
      expect(info.supportsNotification('payment_received'), isTrue);
      expect(info.supportsNotification('unknown_notification'), isFalse);
    });

    test('handles empty methods and notifications', () {
      final partialInfo = PartialNwcInfo();
      final info = partialInfo.dummySign(nielPubkey);

      expect(info.supportedMethods, isEmpty);
      expect(info.supportedNotifications, isEmpty);
      expect(info.supportsMethod('pay_invoice'), isFalse);
      expect(info.supportsNotification('payment_received'), isFalse);
    });

    test('roundtrip serialization', () {
      final partialInfo = PartialNwcInfo(
        supportedMethods: ['pay_invoice', 'get_balance'],
        supportedNotifications: ['payment_received'],
      );

      final original = partialInfo.dummySign(nielPubkey);
      final restored = NwcInfo.fromMap(original.toMap(), ref);

      expect(restored.supportedMethods, original.supportedMethods);
      expect(restored.supportedNotifications, original.supportedNotifications);
      expect(restored.event.id, original.event.id);
    });

    test('has expected method constants', () {
      expect(NwcInfo.payInvoice, 'pay_invoice');
      expect(NwcInfo.multiPayInvoice, 'multi_pay_invoice');
      expect(NwcInfo.payKeysend, 'pay_keysend');
      expect(NwcInfo.multiPayKeysend, 'multi_pay_keysend');
      expect(NwcInfo.makeInvoice, 'make_invoice');
      expect(NwcInfo.lookupInvoice, 'lookup_invoice');
      expect(NwcInfo.listTransactions, 'list_transactions');
      expect(NwcInfo.getBalance, 'get_balance');
      expect(NwcInfo.getInfo, 'get_info');
    });

    test('has expected notification constants', () {
      expect(NwcInfo.paymentReceived, 'payment_received');
      expect(NwcInfo.paymentSent, 'payment_sent');
    });
  });

  group('NwcRequest', () {
    test('creates pay_invoice request', () {
      final partialRequest = PartialNwcRequest.payInvoice(
        walletPubkey: franzapPubkey,
        invoice: 'lnbc1000n1...',
        amount: 1000,
      );

      final request = partialRequest.dummySign(verbirichaPubkey);

      expect(request.event.kind, 23194);
      expect(request.walletPubkey, franzapPubkey);
      expect(request.expiration, isNull);
      expect(request.isExpired, isFalse);
    });

    test('creates request with expiration', () {
      final expiration = DateTime.now().add(Duration(hours: 1));

      final partialRequest = PartialNwcRequest.getBalance(
        walletPubkey: franzapPubkey,
        expiration: expiration,
      );

      final request = partialRequest.dummySign(verbirichaPubkey);

      expect(
        request.expiration?.millisecondsSinceEpoch,
        closeTo(expiration.millisecondsSinceEpoch, 1000),
      );
      expect(request.isExpired, isFalse);
    });

    test('detects expired requests', () {
      final expiration = DateTime.now().subtract(Duration(hours: 1));

      final partialRequest = PartialNwcRequest.getBalance(
        walletPubkey: franzapPubkey,
        expiration: expiration,
      );

      final request = partialRequest.dummySign(verbirichaPubkey);

      expect(request.isExpired, isTrue);
    });

    test('creates make_invoice request', () {
      final partialRequest = PartialNwcRequest.makeInvoice(
        walletPubkey: franzapPubkey,
        amount: 5000,
        description: 'Test invoice',
        expiry: 3600,
      );

      final request = partialRequest.dummySign(verbirichaPubkey);

      expect(request.event.kind, 23194);
      expect(request.walletPubkey, franzapPubkey);
    });

    test('creates get_info request', () {
      final partialRequest = PartialNwcRequest.getInfo(
        walletPubkey: franzapPubkey,
      );

      final request = partialRequest.dummySign(verbirichaPubkey);

      expect(request.event.kind, 23194);
      expect(request.walletPubkey, franzapPubkey);
    });

    test('throws on missing wallet pubkey', () {
      // Create a request without wallet pubkey tag
      final partialRequest = PartialNwcRequest(
        walletPubkey: franzapPubkey,
        method: 'get_balance',
      );

      // Remove the p tag to test error handling
      partialRequest.event.removeTag('p');

      final request = partialRequest.dummySign(verbirichaPubkey);

      expect(() => request.walletPubkey, throwsException);
    });

    test('roundtrip serialization', () {
      final partialRequest = PartialNwcRequest.payInvoice(
        walletPubkey: franzapPubkey,
        invoice: 'lnbc1000n1...',
        amount: 1000,
      );

      final original = partialRequest.dummySign(verbirichaPubkey);
      final restored = NwcRequest.fromMap(original.toMap(), ref);

      expect(restored.walletPubkey, original.walletPubkey);
      expect(restored.encryptedContent, original.encryptedContent);
      expect(restored.event.id, original.event.id);
    });
  });

  group('NwcResponse', () {
    test('creates success response', () {
      final partialResponse = PartialNwcResponse.payInvoiceSuccess(
        clientPubkey: verbirichaPubkey,
        preimage: '0123456789abcdef',
        feesPaid: 100,
        requestEventId:
            'request_event_id_64_chars_00000000000000000000000000000000000',
      );

      final response = partialResponse.dummySign(franzapPubkey);

      expect(response.event.kind, 23195);
      expect(response.clientPubkey, verbirichaPubkey);
      expect(
        response.requestEventId,
        'request_event_id_64_chars_00000000000000000000000000000000000',
      );
    });

    test('creates error response', () {
      final error = NwcError(
        code: NwcError.insufficientBalance,
        message: 'Not enough funds',
      );

      final partialResponse = PartialNwcResponse.error(
        clientPubkey: verbirichaPubkey,
        resultType: 'pay_invoice',
        error: error,
      );

      final response = partialResponse.dummySign(franzapPubkey);

      expect(response.event.kind, 23195);
      expect(response.clientPubkey, verbirichaPubkey);
    });

    test('creates get_balance success response', () {
      final partialResponse = PartialNwcResponse.getBalanceSuccess(
        clientPubkey: verbirichaPubkey,
        balance: 50000,
      );

      final response = partialResponse.dummySign(franzapPubkey);

      expect(response.event.kind, 23195);
      expect(response.clientPubkey, verbirichaPubkey);
    });

    test('creates make_invoice success response', () {
      final partialResponse = PartialNwcResponse.makeInvoiceSuccess(
        clientPubkey: verbirichaPubkey,
        invoice: 'lnbc5000n1...',
        paymentHash:
            'payment_hash_64_chars_000000000000000000000000000000000000000',
        amount: 5000,
        description: 'Test invoice',
        createdAtTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      final response = partialResponse.dummySign(franzapPubkey);

      expect(response.event.kind, 23195);
      expect(response.clientPubkey, verbirichaPubkey);
    });

    test('throws on missing client pubkey', () {
      final partialResponse = PartialNwcResponse.success(
        clientPubkey: verbirichaPubkey,
        resultType: 'get_balance',
        result: {'balance': 1000},
      );

      // Remove the p tag to test error handling
      partialResponse.event.removeTag('p');

      final response = partialResponse.dummySign(franzapPubkey);

      expect(() => response.clientPubkey, throwsException);
    });

    test('roundtrip serialization', () {
      final partialResponse = PartialNwcResponse.getBalanceSuccess(
        clientPubkey: verbirichaPubkey,
        balance: 25000,
      );

      final original = partialResponse.dummySign(franzapPubkey);
      final restored = NwcResponse.fromMap(original.toMap(), ref);

      expect(restored.clientPubkey, original.clientPubkey);
      expect(restored.encryptedContent, original.encryptedContent);
      expect(restored.event.id, original.event.id);
    });
  });

  group('NwcNotification', () {
    test('creates payment_received notification', () {
      final partialNotification = PartialNwcNotification.paymentReceived(
        clientPubkey: verbirichaPubkey,
        invoice: 'lnbc1000n1...',
        preimage: '0123456789abcdef',
        paymentHash:
            'payment_hash_64_chars_000000000000000000000000000000000000000',
        amount: 1000,
        description: 'Payment received',
        settledAtTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      final notification = partialNotification.dummySign(franzapPubkey);

      expect(notification.event.kind, 23196);
      expect(notification.clientPubkey, verbirichaPubkey);
    });

    test('creates payment_sent notification', () {
      final partialNotification = PartialNwcNotification.paymentSent(
        clientPubkey: verbirichaPubkey,
        preimage: '0123456789abcdef',
        paymentHash:
            'payment_hash_64_chars_000000000000000000000000000000000000000',
        amount: 2000,
        invoice: 'lnbc2000n1...',
        feesPaid: 50,
        settledAtTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      final notification = partialNotification.dummySign(franzapPubkey);

      expect(notification.event.kind, 23196);
      expect(notification.clientPubkey, verbirichaPubkey);
    });

    test('throws on missing client pubkey', () {
      final partialNotification = PartialNwcNotification(
        clientPubkey: verbirichaPubkey,
        notificationType: 'payment_received',
        notification: {'amount': 1000},
      );

      // Remove the p tag to test error handling
      partialNotification.event.removeTag('p');

      final notification = partialNotification.dummySign(franzapPubkey);

      expect(() => notification.clientPubkey, throwsException);
    });

    test('roundtrip serialization', () {
      final partialNotification = PartialNwcNotification.paymentReceived(
        clientPubkey: verbirichaPubkey,
        invoice: 'lnbc1000n1...',
        preimage: '0123456789abcdef',
        paymentHash:
            'payment_hash_64_chars_000000000000000000000000000000000000000',
        amount: 1000,
      );

      final original = partialNotification.dummySign(franzapPubkey);
      final restored = NwcNotification.fromMap(original.toMap(), ref);

      expect(restored.clientPubkey, original.clientPubkey);
      expect(restored.encryptedContent, original.encryptedContent);
      expect(restored.event.id, original.event.id);
    });
  });

  group('NwcError', () {
    test('creates from map', () {
      final map = {
        'code': 'INSUFFICIENT_BALANCE',
        'message': 'Not enough funds',
      };

      final error = NwcError.fromMap(map);

      expect(error.code, 'INSUFFICIENT_BALANCE');
      expect(error.message, 'Not enough funds');
    });

    test('converts to map', () {
      final error = NwcError(
        code: NwcError.paymentFailed,
        message: 'Payment could not be completed',
      );

      final map = error.toMap();

      expect(map['code'], NwcError.paymentFailed);
      expect(map['message'], 'Payment could not be completed');
    });

    test('has expected error code constants', () {
      expect(NwcError.rateLimited, 'RATE_LIMITED');
      expect(NwcError.notImplemented, 'NOT_IMPLEMENTED');
      expect(NwcError.insufficientBalance, 'INSUFFICIENT_BALANCE');
      expect(NwcError.quotaExceeded, 'QUOTA_EXCEEDED');
      expect(NwcError.restricted, 'RESTRICTED');
      expect(NwcError.unauthorized, 'UNAUTHORIZED');
      expect(NwcError.internal, 'INTERNAL');
      expect(NwcError.other, 'OTHER');
      expect(NwcError.paymentFailed, 'PAYMENT_FAILED');
      expect(NwcError.notFound, 'NOT_FOUND');
    });

    test('toString returns formatted string', () {
      final error = NwcError(
        code: NwcError.internal,
        message: 'Internal server error',
      );

      expect(
        error.toString(),
        'NwcError(code: INTERNAL, message: Internal server error)',
      );
    });
  });
}

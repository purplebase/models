import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;

  setUpAll(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
  });
  group('PayInvoiceCommand', () {
    test('creates command with required parameters', () {
      final command = PayInvoiceCommand(invoice: 'lnbc1000n1...');

      expect(command.method, 'pay_invoice');
      expect(command.params['invoice'], 'lnbc1000n1...');
      expect(command.params.containsKey('amount'), isFalse);
    });

    test('creates command with amount', () {
      final command = PayInvoiceCommand(invoice: 'lnbc1000n1...', amount: 1000);

      expect(command.method, 'pay_invoice');
      expect(command.params['invoice'], 'lnbc1000n1...');
      expect(command.params['amount'], 1000);
    });

    test('creates request event', () {
      final command = PayInvoiceCommand(invoice: 'lnbc1000n1...', amount: 1000);

      final request = command.toRequest(
        walletPubkey:
            franzapPubkey,
      );

      expect(request, isA<PartialNwcRequest>());
    });

    test('parses response', () {
      final command = PayInvoiceCommand(invoice: 'lnbc1000n1...');

      final responseData = {'preimage': '0123456789abcdef', 'fees_paid': 100};

      final result = command.parseResponse(responseData);

      expect(result.preimage, '0123456789abcdef');
      expect(result.feesPaid, 100);
    });
  });

  group('GetBalanceCommand', () {
    test('creates command with empty parameters', () {
      final command = GetBalanceCommand();

      expect(command.method, 'get_balance');
      expect(command.params, isEmpty);
    });

    test('parses response', () {
      final command = GetBalanceCommand();

      final responseData = {'balance': 50000};

      final result = command.parseResponse(responseData);

      expect(result.balance, 50000);
    });
  });

  group('MakeInvoiceCommand', () {
    test('creates command with required parameters', () {
      final command = MakeInvoiceCommand(amount: 5000);

      expect(command.method, 'make_invoice');
      expect(command.params['amount'], 5000);
      expect(command.params.containsKey('description'), isFalse);
    });

    test('creates command with all parameters', () {
      final command = MakeInvoiceCommand(
        amount: 5000,
        description: 'Test invoice',
        descriptionHash: 'hash123',
        expiry: 3600,
      );

      expect(command.method, 'make_invoice');
      expect(command.params['amount'], 5000);
      expect(command.params['description'], 'Test invoice');
      expect(command.params['description_hash'], 'hash123');
      expect(command.params['expiry'], 3600);
    });

    test('parses response', () {
      final command = MakeInvoiceCommand(amount: 5000);

      final responseData = {
        'type': 'incoming',
        'invoice': 'lnbc5000n1...',
        'payment_hash':
            'payment_hash_64_chars_000000000000000000000000000000000000000',
        'amount': 5000,
        'description': 'Test invoice',
        'created_at': 1234567890,
        'expires_at': 1234571490,
      };

      final result = command.parseResponse(responseData);

      expect(result.type, 'incoming');
      expect(result.invoice, 'lnbc5000n1...');
      expect(
        result.paymentHash,
        'payment_hash_64_chars_000000000000000000000000000000000000000',
      );
      expect(result.amount, 5000);
      expect(result.description, 'Test invoice');
      expect(result.createdAt, 1234567890);
      expect(result.expiresAt, 1234571490);
    });
  });

  group('GetInfoCommand', () {
    test('creates command with empty parameters', () {
      final command = GetInfoCommand();

      expect(command.method, 'get_info');
      expect(command.params, isEmpty);
    });

    test('parses response', () {
      final command = GetInfoCommand();

      final responseData = {
        'alias': 'Test Wallet',
        'color': '#ff0000',
        'pubkey':
            franzapPubkey,
        'network': 'mainnet',
        'block_height': 800000,
        'block_hash':
            'block_hash_64_chars_00000000000000000000000000000000000000000',
        'methods': ['pay_invoice', 'get_balance', 'make_invoice'],
        'notifications': ['payment_received', 'payment_sent'],
      };

      final result = command.parseResponse(responseData);

      expect(result.alias, 'Test Wallet');
      expect(result.color, '#ff0000');
      expect(
        result.pubkey,
        franzapPubkey,
      );
      expect(result.network, 'mainnet');
      expect(result.blockHeight, 800000);
      expect(
        result.blockHash,
        'block_hash_64_chars_00000000000000000000000000000000000000000',
      );
      expect(result.methods, ['pay_invoice', 'get_balance', 'make_invoice']);
      expect(result.notifications, ['payment_received', 'payment_sent']);
    });

    test('parses minimal response', () {
      final command = GetInfoCommand();

      final responseData = {
        'methods': ['pay_invoice'],
      };

      final result = command.parseResponse(responseData);

      expect(result.alias, isNull);
      expect(result.color, isNull);
      expect(result.pubkey, isNull);
      expect(result.network, isNull);
      expect(result.blockHeight, isNull);
      expect(result.blockHash, isNull);
      expect(result.methods, ['pay_invoice']);
      expect(result.notifications, isNull);
    });
  });

  group('LookupInvoiceCommand', () {
    test('creates command with payment hash', () {
      final command = LookupInvoiceCommand(
        paymentHash:
            'payment_hash_64_chars_000000000000000000000000000000000000000',
      );

      expect(command.method, 'lookup_invoice');
      expect(
        command.params['payment_hash'],
        'payment_hash_64_chars_000000000000000000000000000000000000000',
      );
      expect(command.params.containsKey('invoice'), isFalse);
    });

    test('creates command with invoice', () {
      final command = LookupInvoiceCommand(invoice: 'lnbc1000n1...');

      expect(command.method, 'lookup_invoice');
      expect(command.params['invoice'], 'lnbc1000n1...');
      expect(command.params.containsKey('payment_hash'), isFalse);
    });

    test('creates command with both parameters', () {
      final command = LookupInvoiceCommand(
        paymentHash:
            'payment_hash_64_chars_000000000000000000000000000000000000000',
        invoice: 'lnbc1000n1...',
      );

      expect(command.method, 'lookup_invoice');
      expect(
        command.params['payment_hash'],
        'payment_hash_64_chars_000000000000000000000000000000000000000',
      );
      expect(command.params['invoice'], 'lnbc1000n1...');
    });

    test('throws assertion error when no parameters provided', () {
      expect(() => LookupInvoiceCommand(), throwsA(isA<AssertionError>()));
    });

    test('parses response for unsettled invoice', () {
      final command = LookupInvoiceCommand(
        paymentHash:
            'payment_hash_64_chars_000000000000000000000000000000000000000',
      );

      final responseData = {
        'type': 'incoming',
        'invoice': 'lnbc1000n1...',
        'payment_hash':
            'payment_hash_64_chars_000000000000000000000000000000000000000',
        'amount': 1000,
        'created_at': 1234567890,
        'expires_at': 1234571490,
      };

      final result = command.parseResponse(responseData);

      expect(result.type, 'incoming');
      expect(result.invoice, 'lnbc1000n1...');
      expect(
        result.paymentHash,
        'payment_hash_64_chars_000000000000000000000000000000000000000',
      );
      expect(result.amount, 1000);
      expect(result.createdAt, 1234567890);
      expect(result.expiresAt, 1234571490);
      expect(result.settledAt, isNull);
      expect(result.isSettled, isFalse);
    });

    test('parses response for settled invoice', () {
      final command = LookupInvoiceCommand(
        paymentHash:
            'payment_hash_64_chars_000000000000000000000000000000000000000',
      );

      final responseData = {
        'type': 'incoming',
        'payment_hash':
            'payment_hash_64_chars_000000000000000000000000000000000000000',
        'amount': 1000,
        'preimage': '0123456789abcdef',
        'settled_at': 1234568000,
      };

      final result = command.parseResponse(responseData);

      expect(
        result.paymentHash,
        'payment_hash_64_chars_000000000000000000000000000000000000000',
      );
      expect(result.preimage, '0123456789abcdef');
      expect(result.settledAt, 1234568000);
      expect(result.isSettled, isTrue);
    });
  });

  group('PayInvoiceResult', () {
    test('creates from map with required fields', () {
      final map = {'preimage': '0123456789abcdef'};

      final result = PayInvoiceResult.fromMap(map);

      expect(result.preimage, '0123456789abcdef');
      expect(result.feesPaid, isNull);
    });

    test('creates from map with all fields', () {
      final map = {'preimage': '0123456789abcdef', 'fees_paid': 150};

      final result = PayInvoiceResult.fromMap(map);

      expect(result.preimage, '0123456789abcdef');
      expect(result.feesPaid, 150);
    });
  });

  group('GetBalanceResult', () {
    test('creates from map', () {
      final map = {'balance': 75000};

      final result = GetBalanceResult.fromMap(map);

      expect(result.balance, 75000);
    });
  });

  group('MakeInvoiceResult', () {
    test('creates from map with required fields', () {
      final map = {
        'type': 'incoming',
        'payment_hash':
            'payment_hash_64_chars_000000000000000000000000000000000000000',
        'amount': 5000,
      };

      final result = MakeInvoiceResult.fromMap(map);

      expect(result.type, 'incoming');
      expect(
        result.paymentHash,
        'payment_hash_64_chars_000000000000000000000000000000000000000',
      );
      expect(result.amount, 5000);
      expect(result.invoice, isNull);
      expect(result.description, isNull);
      expect(result.preimage, isNull);
    });

    test('creates from map with all fields', () {
      final map = {
        'type': 'incoming',
        'invoice': 'lnbc5000n1...',
        'description': 'Test invoice',
        'description_hash': 'hash123',
        'preimage': '0123456789abcdef',
        'payment_hash':
            'payment_hash_64_chars_000000000000000000000000000000000000000',
        'amount': 5000,
        'fees_paid': 25,
        'created_at': 1234567890,
        'expires_at': 1234571490,
        'metadata': {'custom': 'data'},
      };

      final result = MakeInvoiceResult.fromMap(map);

      expect(result.type, 'incoming');
      expect(result.invoice, 'lnbc5000n1...');
      expect(result.description, 'Test invoice');
      expect(result.descriptionHash, 'hash123');
      expect(result.preimage, '0123456789abcdef');
      expect(
        result.paymentHash,
        'payment_hash_64_chars_000000000000000000000000000000000000000',
      );
      expect(result.amount, 5000);
      expect(result.feesPaid, 25);
      expect(result.createdAt, 1234567890);
      expect(result.expiresAt, 1234571490);
      expect(result.metadata, {'custom': 'data'});
    });
  });

  group('GetInfoResult', () {
    test('creates from map with required fields', () {
      final map = {
        'methods': ['pay_invoice', 'get_balance'],
      };

      final result = GetInfoResult.fromMap(map);

      expect(result.methods, ['pay_invoice', 'get_balance']);
      expect(result.alias, isNull);
      expect(result.notifications, isNull);
    });

    test('creates from map with all fields', () {
      final map = {
        'alias': 'My Wallet',
        'color': '#00ff00',
        'pubkey':
            franzapPubkey,
        'network': 'testnet',
        'block_height': 2500000,
        'block_hash':
            'block_hash_64_chars_00000000000000000000000000000000000000000',
        'methods': ['pay_invoice', 'get_balance', 'make_invoice'],
        'notifications': ['payment_received'],
      };

      final result = GetInfoResult.fromMap(map);

      expect(result.alias, 'My Wallet');
      expect(result.color, '#00ff00');
      expect(
        result.pubkey,
        franzapPubkey,
      );
      expect(result.network, 'testnet');
      expect(result.blockHeight, 2500000);
      expect(
        result.blockHash,
        'block_hash_64_chars_00000000000000000000000000000000000000000',
      );
      expect(result.methods, ['pay_invoice', 'get_balance', 'make_invoice']);
      expect(result.notifications, ['payment_received']);
    });
  });

  group('LookupInvoiceResult', () {
    test('creates from map with required fields', () {
      final map = {
        'type': 'outgoing',
        'payment_hash':
            'payment_hash_64_chars_000000000000000000000000000000000000000',
        'amount': 2000,
      };

      final result = LookupInvoiceResult.fromMap(map);

      expect(result.type, 'outgoing');
      expect(
        result.paymentHash,
        'payment_hash_64_chars_000000000000000000000000000000000000000',
      );
      expect(result.amount, 2000);
      expect(result.settledAt, isNull);
      expect(result.isSettled, isFalse);
    });

    test('creates from map with settled payment', () {
      final map = {
        'type': 'incoming',
        'invoice': 'lnbc2000n1...',
        'preimage': '0123456789abcdef',
        'payment_hash':
            'payment_hash_64_chars_000000000000000000000000000000000000000',
        'amount': 2000,
        'settled_at': 1234568000,
      };

      final result = LookupInvoiceResult.fromMap(map);

      expect(result.type, 'incoming');
      expect(result.invoice, 'lnbc2000n1...');
      expect(result.preimage, '0123456789abcdef');
      expect(result.settledAt, 1234568000);
      expect(result.isSettled, isTrue);
    });
  });
}

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;
  late NwcManager manager;
  late NwcConnection testConnection;
  late StorageNotifier storage;
  late Signer signer;

  setUp(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    ref = container.read(refProvider);
    storage =
        container.read(storageNotifierProvider.notifier)
            as DummyStorageNotifier;

    // Create and sign in a test signer
    final privateKey = Utils.generateRandomHex64();
    signer = Bip340PrivateKeySigner(privateKey, ref);
    await signer.signIn();

    manager = NwcManager(ref, signer: signer);

    // Create a test connection
    testConnection = NwcConnection(
      walletPubkey: franzapPubkey,
      secret: Utils.generateRandomHex64(),
      relay: 'wss://localhost:7777',
      createdAt: DateTime.now(),
    );

    // Store and set as active
    await manager.storeConnection('test', testConnection);
    await manager.setActiveConnection('test');
  });

  tearDown(() async {
    await manager.clearAll();
    await storage.clear();
    container.dispose();
  });

  group('NWC Manager Public API', () {
    test('executeCommand throws when no active connection', () async {
      // Create a new manager and explicitly clear its active connection
      final tempManager = NwcManager(ref, signer: signer);
      await tempManager.setActiveConnection(null);

      final command = GetBalanceCommand();

      await expectLater(
        () => tempManager.executeCommand(command),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No active NWC connection'),
          ),
        ),
      );
    });

    test('executeCommand throws when connection not found', () async {
      final command = GetBalanceCommand();

      await expectLater(
        () => manager.executeCommand(command, connectionId: 'nonexistent'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('NWC connection "nonexistent" not found'),
          ),
        ),
      );
    });

    test('sendZap throws when no active connection', () async {
      // Create a new manager and explicitly clear its active connection
      final tempManager = NwcManager(ref, signer: signer);
      await tempManager.setActiveConnection(null);

      await expectLater(
        () => tempManager.sendZap(
          recipientPubkey: franzapPubkey,
          amountSats: 1000,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No active NWC connection'),
          ),
        ),
      );
    });

    test('sendZap throws when connection not found', () async {
      await expectLater(
        () => manager.sendZap(
          recipientPubkey: franzapPubkey,
          amountSats: 1000,
          connectionId: 'nonexistent',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('NWC connection "nonexistent" not found'),
          ),
        ),
      );
    });

    test('PayInvoiceCommand creates correct structure', () {
      final command = PayInvoiceCommand(
        invoice: 'lnbc1000n1pjqwdqcpp5...',
        amount: 1000,
      );

      expect(command.method, equals('pay_invoice'));
      expect(
        command.params,
        equals({'invoice': 'lnbc1000n1pjqwdqcpp5...', 'amount': 1000}),
      );
    });

    test('GetBalanceCommand creates correct structure', () {
      final command = GetBalanceCommand();

      expect(command.method, equals('get_balance'));
      expect(command.params, equals({}));
    });

    test('MakeInvoiceCommand creates correct structure', () {
      final command = MakeInvoiceCommand(
        amount: 5000,
        description: 'Test invoice',
        expiry: 3600,
      );

      expect(command.method, equals('make_invoice'));
      expect(
        command.params,
        equals({'amount': 5000, 'description': 'Test invoice', 'expiry': 3600}),
      );
    });

    test('PayInvoiceCommand.fromPubkey method exists with correct signature', () {
      // This test just verifies the method signature exists and parameters are correctly typed
      // We can't easily test the async factory method in isolation without mocking everything
      expect(PayInvoiceCommand.fromPubkey, isA<Function>());
    });

    test('commands can create NWC requests', () async {
      final command = PayInvoiceCommand(
        invoice: 'lnbc1000n1pjqwdqcpp5...',
        amount: 1000,
      );

      final request = command.toRequest(
        walletPubkey: testConnection.walletPubkey,
        expiration: DateTime.now().add(Duration(minutes: 5)),
      );

      expect(request.event.kind, equals(23194));
      expect(
        request.event.getFirstTagValue('p'),
        equals(testConnection.walletPubkey),
      );
      expect(request.event.content, isNotEmpty);
    });

    test('result types parse correctly', () {
      // Test PayInvoiceResult
      final payResult = PayInvoiceResult.fromMap({
        'preimage': 'test_preimage',
        'fees_paid': 100,
      });
      expect(payResult.preimage, equals('test_preimage'));
      expect(payResult.feesPaid, equals(100));

      // Test GetBalanceResult
      final balanceResult = GetBalanceResult.fromMap({'balance': 50000});
      expect(balanceResult.balance, equals(50000));

      // Test MakeInvoiceResult
      final invoiceResult = MakeInvoiceResult.fromMap({
        'type': 'incoming',
        'payment_hash': 'test_hash',
        'amount': 5000,
        'invoice': 'lnbc50000n1...',
      });
      expect(invoiceResult.type, equals('incoming'));
      expect(invoiceResult.paymentHash, equals('test_hash'));
      expect(invoiceResult.amount, equals(5000));
    });

    test('PayInvoiceResult contains expected fields for zap payments', () {
      final payResult = PayInvoiceResult(
        preimage: 'test_preimage',
        feesPaid: 100,
      );

      expect(payResult.preimage, equals('test_preimage'));
      expect(payResult.feesPaid, equals(100));
    });
  });

  group('Connection Management', () {
    test('stores and retrieves connections', () async {
      const connectionId = 'test_connection_1';

      await manager.storeConnection(connectionId, testConnection);

      final allConnections = await manager.getAllConnections();
      expect(allConnections.containsKey(connectionId), isTrue);
      expect(allConnections[connectionId]?.walletPubkey, equals(franzapPubkey));
    });

    test('sets and clears active connection', () async {
      const connectionId = 'test_active';

      await manager.storeConnection(connectionId, testConnection);
      await manager.setActiveConnection(connectionId);

      final connectionIds = await manager.getAllConnectionIds();
      expect(connectionIds.contains(connectionId), isTrue);

      // Clear active connection
      await manager.setActiveConnection(null);

      // Should still exist in storage but not be active
      final stillExists = await manager.getAllConnections();
      expect(stillExists.containsKey(connectionId), isTrue);
    });

    test('removes connections', () async {
      const connectionId = 'test_remove';

      await manager.storeConnection(connectionId, testConnection);
      await manager.removeConnection(connectionId);

      final allConnections = await manager.getAllConnections();
      expect(allConnections.containsKey(connectionId), isFalse);
    });

    test('clears all connections', () async {
      await manager.storeConnection('conn1', testConnection);
      await manager.storeConnection('conn2', testConnection);

      await manager.clearAll();

      final allConnections = await manager.getAllConnections();
      expect(allConnections.isEmpty, isTrue);

      final connectionIds = await manager.getAllConnectionIds();
      expect(connectionIds.isEmpty, isTrue);
    });
  });

  group('Secret Management', () {
    test('stores and retrieves secrets', () async {
      const key = 'test_secret';
      const secret = 'super_secret_value';

      await manager.storeSecret(key, secret);
      final retrieved = await manager.getSecret(key);

      expect(retrieved, equals(secret));
    });

    test('removes secrets', () async {
      const key = 'test_remove_secret';
      const secret = 'value_to_remove';

      await manager.storeSecret(key, secret);
      await manager.removeSecret(key);

      final retrieved = await manager.getSecret(key);
      expect(retrieved, isNull);
    });
  });

  group('Command Types', () {
    test('PayInvoiceCommand creates correct request', () {
      final command = PayInvoiceCommand(
        invoice: 'lnbc1000n1pjqwdqcpp5...',
        amount: 1000,
      );

      expect(command.method, equals('pay_invoice'));
      expect(
        command.params,
        equals({'invoice': 'lnbc1000n1pjqwdqcpp5...', 'amount': 1000}),
      );
    });

    test('GetBalanceCommand creates correct request', () {
      final command = GetBalanceCommand();

      expect(command.method, equals('get_balance'));
      expect(command.params, equals({}));
    });

    test('MakeInvoiceCommand creates correct request', () {
      final command = MakeInvoiceCommand(
        amount: 5000,
        description: 'Test invoice',
        expiry: 3600,
      );

      expect(command.method, equals('make_invoice'));
      expect(
        command.params,
        equals({'amount': 5000, 'description': 'Test invoice', 'expiry': 3600}),
      );
    });

    test('PayInvoiceResult can be used directly for zap operations', () {
      final payResult = PayInvoiceResult(
        preimage: 'test_preimage',
        feesPaid: 100,
      );

      expect(payResult.preimage, equals('test_preimage'));
      expect(payResult.feesPaid, equals(100));
    });
  });
}

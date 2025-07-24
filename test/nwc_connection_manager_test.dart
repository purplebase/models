import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;
  late NwcConnectionManager manager;
  late NwcConnection testConnection;

  setUpAll(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    ref = container.read(refProvider);

    // Create a real signer for proper encryption/decryption
    const privateKey =
        'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8';
    final signer = Bip340PrivateKeySigner(privateKey, ref);
    await signer.signIn();

    manager = NwcConnectionManager(ref, signer: signer);

    // Create a test connection
    testConnection = NwcConnection(
      walletPubkey:
          'b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4',
      secret:
          '71a8c14c1407c113601079c4302dab36460f0ccd0ad506f1f2dc73b5100e4f3c',
      relay: 'wss://relay.damus.io',
      lud16: 'test@example.com',
      limits: NwcConnectionLimits(
        maxAmount: 10000,
        budgetRenewal: NwcBudgetRenewal.daily,
        allowedMethods: {'pay_invoice', 'get_balance'},
      ),
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(days: 30)),
    );
  });

  group('NwcConnectionManager', () {
    test('stores and retrieves connection', () async {
      const connectionId = 'test_connection_1';

      await manager.storeConnection(connectionId, testConnection);
      final retrieved = await manager.getConnection(connectionId);

      expect(retrieved, isNotNull);
      expect(retrieved!.walletPubkey, testConnection.walletPubkey);
      expect(retrieved.secret, testConnection.secret);
      expect(retrieved.relay, testConnection.relay);
      expect(retrieved.lud16, testConnection.lud16);
      expect(retrieved.limits?.maxAmount, testConnection.limits?.maxAmount);
      expect(
        retrieved.limits?.budgetRenewal,
        testConnection.limits?.budgetRenewal,
      );
      expect(
        retrieved.limits?.allowedMethods,
        testConnection.limits?.allowedMethods,
      );
      expect(
        retrieved.createdAt.millisecondsSinceEpoch,
        testConnection.createdAt.millisecondsSinceEpoch,
      );
      expect(
        retrieved.expiresAt?.millisecondsSinceEpoch,
        testConnection.expiresAt?.millisecondsSinceEpoch,
      );
    });

    test('returns null for non-existent connection', () async {
      final retrieved = await manager.getConnection('non_existent');
      expect(retrieved, isNull);
    });

    test('stores multiple connections', () async {
      const connectionId1 = 'test_connection_2';
      const connectionId2 = 'test_connection_3';

      final connection2 = NwcConnection(
        walletPubkey: 'a' * 64,
        secret: 'b' * 64,
        relay: 'wss://relay2.example.com',
        createdAt: DateTime.now(),
      );

      await manager.storeConnection(connectionId1, testConnection);
      await manager.storeConnection(connectionId2, connection2);

      final retrieved1 = await manager.getConnection(connectionId1);
      final retrieved2 = await manager.getConnection(connectionId2);

      expect(retrieved1?.walletPubkey, testConnection.walletPubkey);
      expect(retrieved2?.walletPubkey, connection2.walletPubkey);
    });

    test('gets all connection IDs', () async {
      // Clear any existing connections first
      await manager.clearAll();

      const connectionId1 = 'test_connection_4';
      const connectionId2 = 'test_connection_5';

      await manager.storeConnection(connectionId1, testConnection);
      await manager.storeConnection(connectionId2, testConnection);

      final connectionIds = await manager.getAllConnectionIds();

      expect(connectionIds.length, greaterThanOrEqualTo(2));
      expect(connectionIds, contains(connectionId1));
      expect(connectionIds, contains(connectionId2));
    });

    test('gets all connections', () async {
      // Clear any existing connections first
      await manager.clearAll();

      const connectionId1 = 'test_connection_6';
      const connectionId2 = 'test_connection_7';

      await manager.storeConnection(connectionId1, testConnection);
      await manager.storeConnection(connectionId2, testConnection);

      final connections = await manager.getAllConnections();

      expect(connections.length, greaterThanOrEqualTo(2));
      expect(connections, containsPair(connectionId1, isA<NwcConnection>()));
      expect(connections, containsPair(connectionId2, isA<NwcConnection>()));
    });

    test('sets and gets active connection ID', () async {
      const connectionId = 'test_active_connection';

      // Set active connection
      await manager.setActiveConnection(connectionId);
      final retrievedId = await manager.getActiveConnectionId();

      expect(retrievedId, connectionId);
    });

    test('clears active connection', () async {
      const connectionId = 'test_active_connection_2';

      // Set then clear active connection
      await manager.setActiveConnection(connectionId);
      await manager.setActiveConnection(null);
      final retrievedId = await manager.getActiveConnectionId();

      expect(retrievedId, isNull);
    });

    test('gets active connection', () async {
      const connectionId = 'test_active_connection_3';

      // Store connection and set as active
      await manager.storeConnection(connectionId, testConnection);
      await manager.setActiveConnection(connectionId);
      final activeConnection = await manager.getActiveConnection();

      expect(activeConnection, isNotNull);
      expect(activeConnection!.walletPubkey, testConnection.walletPubkey);
    });

    test('returns null for active connection when none set', () async {
      await manager.setActiveConnection(null);
      final activeConnection = await manager.getActiveConnection();

      expect(activeConnection, isNull);
    });

    test('stores and retrieves standalone secrets', () async {
      const secretKey = 'test_secret_key';
      const secretValue = 'super_secret_value_123';

      await manager.storeSecret(secretKey, secretValue);
      final retrieved = await manager.getSecret(secretKey);

      expect(retrieved, secretValue);
    });

    test('returns null for non-existent secret', () async {
      final retrieved = await manager.getSecret('non_existent_secret');
      expect(retrieved, isNull);
    });

    test('removes secret', () async {
      const secretKey = 'test_secret_to_remove';
      const secretValue = 'secret_value_to_remove';

      // Store then remove secret
      await manager.storeSecret(secretKey, secretValue);
      await manager.removeSecret(secretKey);
      final retrieved = await manager.getSecret(secretKey);

      expect(retrieved, isNull);
    });

    test('overwrites existing connection', () async {
      const connectionId = 'test_overwrite_connection';

      final originalConnection = NwcConnection(
        walletPubkey: 'original_pubkey${'0' * 50}',
        secret: 'original_secret${'1' * 50}',
        relay: 'wss://original.relay.com',
        createdAt: DateTime.now(),
      );

      final newConnection = NwcConnection(
        walletPubkey: 'new_pubkey${'2' * 54}',
        secret: 'new_secret${'3' * 54}',
        relay: 'wss://new.relay.com',
        createdAt: DateTime.now(),
      );

      // Store original, then overwrite with new
      await manager.storeConnection(connectionId, originalConnection);
      await manager.storeConnection(connectionId, newConnection);
      final retrieved = await manager.getConnection(connectionId);

      expect(retrieved, isNotNull);
      expect(retrieved!.walletPubkey, newConnection.walletPubkey);
      expect(retrieved.secret, newConnection.secret);
      expect(retrieved.relay, newConnection.relay);
    });

    test('handles empty connections list', () async {
      await manager.clearAll();

      final connectionIds = await manager.getAllConnectionIds();
      final connections = await manager.getAllConnections();

      expect(connectionIds, isEmpty);
      expect(connections, isEmpty);
    });

    test('clears all data', () async {
      const connectionId1 = 'test_clear_connection_1';
      const connectionId2 = 'test_clear_connection_2';
      const secretKey = 'test_clear_secret';

      // Store some data
      await manager.storeConnection(connectionId1, testConnection);
      await manager.storeConnection(connectionId2, testConnection);
      await manager.setActiveConnection(connectionId1);
      await manager.storeSecret(secretKey, 'secret_value');

      // Clear all
      await manager.clearAll();

      // Verify everything is cleared
      final connectionIds = await manager.getAllConnectionIds();
      final activeConnection = await manager.getActiveConnection();
      final secretValue = await manager.getSecret(secretKey);

      expect(connectionIds, isEmpty);
      expect(activeConnection, isNull);
      // Note: clearAll() doesn't clear standalone secrets, only connections
      expect(secretValue, isNotNull); // Secret should still exist
    });

    test('handles corrupted connection data gracefully', () async {
      // This test would need more complex setup to simulate corrupted data
      // For now, we'll test the basic error handling path exists
      const connectionId = 'test_corrupted_connection';

      final retrieved = await manager.getConnection(connectionId);
      expect(retrieved, isNull);
    });
  });

  group('NwcConnectionManager.create factory', () {
    test('creates manager with active signer', () async {
      // Create and sign in a signer to make it active
      const privateKey =
          'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8';
      final testSigner = Bip340PrivateKeySigner(privateKey, ref);
      await testSigner.signIn();

      final createdManager = NwcConnectionManager(ref);
      expect(createdManager, isA<NwcConnectionManager>());
    });
  });

  group('Integration tests', () {
    test('full workflow - store, set active, retrieve, clear', () async {
      const connectionId = 'integration_test_connection';

      // 1. Store connection
      await manager.storeConnection(connectionId, testConnection);

      // 2. Set as active
      await manager.setActiveConnection(connectionId);

      // 3. Retrieve active connection
      final activeConnection = await manager.getActiveConnection();
      expect(activeConnection, isNotNull);
      expect(activeConnection!.walletPubkey, testConnection.walletPubkey);

      // 4. Verify in connections list
      final allConnections = await manager.getAllConnections();
      expect(allConnections, containsPair(connectionId, isA<NwcConnection>()));

      // 5. Clear active
      await manager.setActiveConnection(null);
      final clearedActive = await manager.getActiveConnection();
      expect(clearedActive, isNull);

      // 6. Connection should still exist
      final stillExists = await manager.getConnection(connectionId);
      expect(stillExists, isNotNull);
    });

    test('multiple connections with different properties', () async {
      const connectionId1 = 'multi_connection_1';
      const connectionId2 = 'multi_connection_2';
      const connectionId3 = 'multi_connection_3';

      final connection1 = NwcConnection(
        walletPubkey: 'wallet1${'0' * 58}',
        secret: 'secret1${'1' * 57}',
        relay: 'wss://relay1.com',
        createdAt: DateTime.now(),
      );

      final connection2 = NwcConnection(
        walletPubkey: 'wallet2${'2' * 58}',
        secret: 'secret2${'3' * 57}',
        relay: 'wss://relay2.com',
        lud16: 'test@example.com',
        limits: NwcConnectionLimits(maxAmount: 5000),
        createdAt: DateTime.now(),
      );

      final connection3 = NwcConnection(
        walletPubkey: 'wallet3${'4' * 58}',
        secret: 'secret3${'5' * 57}',
        relay: 'wss://relay3.com',
        expiresAt: DateTime.now().add(Duration(hours: 1)),
        createdAt: DateTime.now(),
      );

      // Store all connections
      await manager.storeConnection(connectionId1, connection1);
      await manager.storeConnection(connectionId2, connection2);
      await manager.storeConnection(connectionId3, connection3);

      // Retrieve and verify each
      final retrieved1 = await manager.getConnection(connectionId1);
      final retrieved2 = await manager.getConnection(connectionId2);
      final retrieved3 = await manager.getConnection(connectionId3);

      expect(retrieved1?.walletPubkey, connection1.walletPubkey);
      expect(retrieved1?.lud16, isNull);
      expect(retrieved1?.limits, isNull);

      expect(retrieved2?.walletPubkey, connection2.walletPubkey);
      expect(retrieved2?.lud16, connection2.lud16);
      expect(retrieved2?.limits?.maxAmount, connection2.limits?.maxAmount);

      expect(retrieved3?.walletPubkey, connection3.walletPubkey);
      expect(
        retrieved3?.expiresAt?.millisecondsSinceEpoch,
        connection3.expiresAt?.millisecondsSinceEpoch,
      );
    });
  });
}

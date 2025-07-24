import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;
  late NwcManager manager;
  late NwcConnection testConnection;

  setUp(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    ref = container.read(refProvider);

    // Create and sign in a test signer
    final privateKey = Utils.generateRandomHex64();
    final signer = Bip340PrivateKeySigner(privateKey, ref);
    await signer.signIn();

    manager = NwcManager(ref, signer: signer);

    // Create a test connection
    testConnection = NwcConnection(
      walletPubkey: franzapPubkey,
      secret: Utils.generateRandomHex64(),
      relay: 'wss://localhost:7777',
      createdAt: DateTime.now(),
    );
  });

  tearDown(() async {
    await manager.clearAll();

    // Clear the relay storage to ensure test isolation
    final relay = ref.read(relayProvider);
    relay.deleteEvents(); // This clears all events from storage

    container.dispose();
  });

  group('NwcManager', () {
    test('stores and retrieves connection', () async {
      const connectionId = 'test_connection_1';

      // Store connection
      await manager.storeConnection(connectionId, testConnection);

      // Retrieve all connections
      final connections = await manager.getAllConnections();
      expect(connections[connectionId]?.walletPubkey, equals(franzapPubkey));
      expect(connections[connectionId]?.relay, equals('wss://localhost:7777'));
    });

    test('handles multiple connections', () async {
      final connection1 = NwcConnection(
        walletPubkey: franzapPubkey,
        secret: Utils.generateRandomHex64(),
        relay: 'wss://localhost:7777',
        createdAt: DateTime.now(),
      );

      final connection2 = NwcConnection(
        walletPubkey: verbirichaPubkey,
        secret: Utils.generateRandomHex64(),
        relay: 'wss://localhost:7778',
        createdAt: DateTime.now(),
      );

      await manager.storeConnection('conn1', connection1);
      await manager.storeConnection('conn2', connection2);

      final allConnections = await manager.getAllConnections();
      expect(allConnections.length, equals(2));
      expect(allConnections['conn1']?.walletPubkey, equals(franzapPubkey));
      expect(allConnections['conn2']?.walletPubkey, equals(verbirichaPubkey));
    });

    test('removes connection', () async {
      const connectionId = 'test_remove';

      await manager.storeConnection(connectionId, testConnection);
      await manager.removeConnection(connectionId);

      final connections = await manager.getAllConnections();
      expect(connections.containsKey(connectionId), isFalse);
    });

    test('manages active connection', () async {
      const connectionId = 'test_active';

      await manager.storeConnection(connectionId, testConnection);
      await manager.setActiveConnection(connectionId);

      // Verify connection is stored
      final allConnections = await manager.getAllConnections();
      expect(allConnections.containsKey(connectionId), isTrue);

      // Clear active connection
      await manager.setActiveConnection(null);

      // Connection should still exist but not be active
      final stillExists = await manager.getAllConnections();
      expect(stillExists.containsKey(connectionId), isTrue);
    });

    test('gets all connection IDs', () async {
      await manager.clearAll(); // Start fresh

      await manager.storeConnection('id1', testConnection);
      await manager.storeConnection('id2', testConnection);
      await manager.storeConnection('id3', testConnection);

      final ids = await manager.getAllConnectionIds();
      expect(ids.length, equals(3));
      expect(ids.contains('id1'), isTrue);
      expect(ids.contains('id2'), isTrue);
      expect(ids.contains('id3'), isTrue);
    });

    test('clears all connections and active state', () async {
      await manager.storeConnection('temp1', testConnection);
      await manager.storeConnection('temp2', testConnection);
      await manager.setActiveConnection('temp1');

      await manager.clearAll();

      // Force a fresh query from storage
      final connections = await manager.getAllConnections();
      expect(connections.isEmpty, isTrue);

      final ids = await manager.getAllConnectionIds();
      expect(ids.isEmpty, isTrue);
    });

    test('handles secret storage', () async {
      const key = 'test_key';
      const secret = 'test_secret_value';

      await manager.storeSecret(key, secret);
      final retrieved = await manager.getSecret(key);
      expect(retrieved, equals(secret));
    });

    test('removes secrets', () async {
      const key = 'remove_test';
      const secret = 'value_to_remove';

      await manager.storeSecret(key, secret);
      await manager.removeSecret(key);

      final retrieved = await manager.getSecret(key);
      expect(retrieved, isNull);
    });

    test('executeCommand throws without active connection', () async {
      // Create a fresh manager without active connection
      final tempSigner = Bip340PrivateKeySigner(
        Utils.generateRandomHex64(),
        ref,
      );
      await tempSigner.signIn();
      final tempManager = NwcManager(ref, signer: tempSigner);

      final command = GetBalanceCommand();

      expect(
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
  });

  group('NwcManager Provider', () {
    test('creates manager with active signer', () async {
      // Create and sign in a signer to make it active
      final testSigner = Bip340PrivateKeySigner(
        Utils.generateRandomHex64(),
        ref,
      );
      await testSigner.signIn();

      final createdManager = NwcManager(ref);
      expect(createdManager, isA<NwcManager>());
    });
  });
}

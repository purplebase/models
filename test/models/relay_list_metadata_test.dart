import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    storage =
        container.read(storageNotifierProvider.notifier)
            as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.cancel();
    await storage.clear();
    container.dispose();
  });

  group('RelayListMetadata', () {
    test('basic relay list creation', () {
      final relayList = PartialRelayListMetadata(
        writeRelays: {'wss://relay1.example.com'},
        readRelays: {'wss://relay2.example.com'},
        bothRelays: {'wss://relay3.example.com'},
      ).dummySign(nielPubkey);

      expect(relayList.allRelayUrls.length, 3);
      expect(
        relayList.writeRelays,
        containsAll(['wss://relay1.example.com', 'wss://relay3.example.com']),
      );
      expect(
        relayList.readRelays,
        containsAll(['wss://relay2.example.com', 'wss://relay3.example.com']),
      );
    });

    test('empty relay list', () {
      final relayList = PartialRelayListMetadata().dummySign(nielPubkey);
      expect(relayList.allRelayUrls, isEmpty);
    });

    test('event kind and structure', () {
      final relayList = PartialRelayListMetadata(
        readRelays: {'wss://test.relay.com'},
      ).dummySign(nielPubkey);

      expect(relayList.event.kind, 10002);
      expect(relayList.event.content, '');

      final rTags = relayList.event.getTagSet('r');
      expect(rTags.length, 1);
      expect(rTags.first[0], 'r');
      expect(rTags.first[1], 'wss://test.relay.com');
      if (rTags.first.length > 2) {
        expect(rTags.first[2], ''); // Middle position is empty
      }
      if (rTags.first.length > 3) {
        expect(rTags.first[3], 'read'); // Read flag in position 3
      }
    });

    test('partial model methods', () {
      final partial = PartialRelayListMetadata();

      // Test relay management
      partial.addRelay('wss://relay1.com');
      partial.addReadRelay('wss://relay2.com');
      partial.addWriteRelay('wss://relay3.com');

      expect(partial.allRelayUrls.length, 3);
      expect(
        partial.allRelayUrls,
        containsAll([
          'wss://relay1.com',
          'wss://relay2.com',
          'wss://relay3.com',
        ]),
      );

      partial.removeRelay('wss://relay1.com');
      expect(partial.allRelayUrls.length, 2);
      expect(partial.allRelayUrls.contains('wss://relay1.com'), false);
    });
  });
}

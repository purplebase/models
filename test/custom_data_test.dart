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

  group('CustomData', () {
    test('should create CustomData from map', () {
      final ref = container.read(refProvider);

      final customDataMap = {
        'id': 'test_id',
        'pubkey': nielPubkey,
        'created_at': 1234567890,
        'kind': 30078,
        'content': '{"key": "value"}',
        'tags': [
          ['d', 'test_identifier'],
        ],
        'sig': 'test_sig',
      };

      final customData = CustomData.fromMap(customDataMap, ref);

      expect(customData.content, '{"key": "value"}');
      expect(customData.identifier, 'test_identifier');
    });

    test('should create PartialCustomData', () {
      final partialCustomData = PartialCustomData(
        identifier: 'test_identifier',
        content: '{"key": "value"}',
      );

      expect(partialCustomData.identifier, 'test_identifier');
      expect(partialCustomData.event.content, '{"key": "value"}');
    });
  });
}

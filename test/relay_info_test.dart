import 'dart:convert';
import 'package:test/test.dart';
import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;

  setUpAll(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    ref = container.read(refProvider);
  });

  group('RelayInfo', () {
    test('should parse relay info from JSON', () {
      final json = {
        'id': 'test-id',
        'content': jsonEncode({
          'name': 'Test Relay',
          'description': 'A test relay',
          'supported_nips': [1, 2, 9, 10, 11],
          'software': 'test-relay',
          'version': '1.0.0',
          'contact': 'test@example.com',
          'pubkey':
              'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be',
          'icon': 'https://example.com/icon.png',
        }),
        'created_at': DateTime.now().toSeconds(),
        'pubkey':
            'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be',
        'kind': 11,
        'tags': [],
        'sig': 'test-signature',
      };

      final relayInfo = RelayInfo.fromMap(json, ref);

      expect(relayInfo.name, equals('Test Relay'));
      expect(relayInfo.description, equals('A test relay'));
      expect(relayInfo.supportedNips, equals([1, 2, 9, 10, 11]));
      expect(relayInfo.software, equals('test-relay'));
      expect(relayInfo.version, equals('1.0.0'));
      expect(relayInfo.contact, equals('test@example.com'));
      expect(
        relayInfo.relayPubkey,
        equals(
          'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be',
        ),
      );
      expect(relayInfo.icon, equals('https://example.com/icon.png'));
    });

    test('should handle missing optional fields', () {
      final json = {
        'id': 'test-id',
        'content': jsonEncode({
          'name': 'Test Relay',
          'description': 'A test relay',
          'supported_nips': [1, 2],
          'software': 'test-relay',
          'version': '1.0.0',
          'contact': 'test@example.com',
        }),
        'created_at': DateTime.now().toSeconds(),
        'pubkey':
            'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be',
        'kind': 11,
        'tags': [],
        'sig': 'test-signature',
      };

      final relayInfo = RelayInfo.fromMap(json, ref);

      expect(relayInfo.name, equals('Test Relay'));
      expect(relayInfo.relayPubkey, isNull);
      expect(relayInfo.icon, isNull);
      expect(relayInfo.supportedNipsDetails, isNull);
    });
  });

  group('RelayInfoData', () {
    test('should create relay info data', () {
      final relayInfo = RelayInfoData(
        name: 'Test Relay',
        description: 'A test relay',
        supportedNips: [1, 2, 9, 10, 11],
        software: 'test-relay',
        version: '1.0.0',
        contact: 'test@example.com',
        pubkey:
            'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be',
        icon: 'https://example.com/icon.png',
      );

      expect(relayInfo.name, equals('Test Relay'));
      expect(relayInfo.description, equals('A test relay'));
      expect(relayInfo.supportedNips, equals([1, 2, 9, 10, 11]));
      expect(relayInfo.software, equals('test-relay'));
      expect(relayInfo.version, equals('1.0.0'));
      expect(relayInfo.contact, equals('test@example.com'));
      expect(
        relayInfo.pubkey,
        equals(
          'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be',
        ),
      );
      expect(relayInfo.icon, equals('https://example.com/icon.png'));
    });

    test('should convert to JSON', () {
      final relayInfo = RelayInfoData(
        name: 'Test Relay',
        description: 'A test relay',
        supportedNips: [1, 2, 9, 10, 11],
        software: 'test-relay',
        version: '1.0.0',
        contact: 'test@example.com',
      );

      final json = relayInfo.toJson();
      final parsed = jsonDecode(json);

      expect(parsed['name'], equals('Test Relay'));
      expect(parsed['description'], equals('A test relay'));
      expect(parsed['supported_nips'], equals([1, 2, 9, 10, 11]));
      expect(parsed['software'], equals('test-relay'));
      expect(parsed['version'], equals('1.0.0'));
      expect(parsed['contact'], equals('test@example.com'));
      expect(parsed.containsKey('pubkey'), isFalse);
      expect(parsed.containsKey('icon'), isFalse);
    });
  });
}

import 'dart:convert';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
    storage =
        container.read(storageNotifierProvider.notifier)
            as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.clear();
    container.dispose();
  });

  group('CustomData', () {
    test('basic custom data creation and properties', () {
      const testContent =
          '{"app":"myapp","version":"1.0","settings":{"theme":"dark"}}';
      final customData = PartialCustomData(
        identifier: 'user-preferences',
        content: testContent,
      ).dummySign(nielPubkey);

      expect(customData.event.kind, 30078);
      expect(customData.content, equals(testContent));
      expect(customData.identifier, equals('user-preferences'));
    });

    test('handles different content types', () {
      // JSON content
      final jsonData = PartialCustomData(
        identifier: 'json-data',
        content: '{"key": "value", "number": 42}',
      ).dummySign(nielPubkey);

      expect(jsonData.content, contains('"key": "value"'));

      // Plain text content
      final textData = PartialCustomData(
        identifier: 'text-data',
        content: 'This is plain text content',
      ).dummySign(nielPubkey);

      expect(textData.content, equals('This is plain text content'));

      // Empty content
      final emptyData = PartialCustomData(
        identifier: 'empty-data',
        content: '',
      ).dummySign(nielPubkey);

      expect(emptyData.content, isEmpty);
    });

    test('event structure and tags', () {
      final customData = PartialCustomData(
        identifier: 'test-data',
        content: 'test content',
      ).dummySign(nielPubkey);

      expect(customData.event.kind, 30078);
      expect(customData.event.getFirstTagValue('d'), equals('test-data'));
      expect(customData.event.content, equals('test content'));
    });

    test('custom properties as tags', () {
      final partial = PartialCustomData(
        identifier: 'configurable-data',
        content: 'main content',
      );

      // Set custom properties
      partial.setProperty('category', 'user-settings');
      partial.setProperty('priority', 'high');
      partial.setProperty('expires', '2024-12-31');

      final customData = partial.dummySign(nielPubkey);

      // Verify properties are stored as tags
      expect(
        customData.event.getFirstTagValue('category'),
        equals('user-settings'),
      );
      expect(customData.event.getFirstTagValue('priority'), equals('high'));
      expect(
        customData.event.getFirstTagValue('expires'),
        equals('2024-12-31'),
      );

      // Test getting properties
      expect(partial.getProperty('category'), equals('user-settings'));
      expect(partial.getProperty('nonexistent'), isNull);
    });

    test('identifier uniqueness and replaceability', () async {
      // Create first version
      final data1 = PartialCustomData(
        identifier: 'shared-id',
        content: 'version 1',
      ).dummySign(nielPubkey);

      await storage.save({data1});

      // Create second version with same identifier (should replace)
      final data2 = PartialCustomData(
        identifier: 'shared-id',
        content: 'version 2',
      ).dummySign(nielPubkey);

      await storage.save({data2});

      // Query should return only the latest version
      final retrieved = await storage.query(
        Request<CustomData>.fromIds({data2.id}),
      );
      expect(retrieved.length, 1);
      expect(retrieved.first.content, equals('version 2'));
      expect(retrieved.first.identifier, equals('shared-id'));
    });
  });

  group('CustomData Storage and Retrieval', () {
    test('saves and loads custom data', () async {
      final customData = PartialCustomData(
        identifier: 'stored-data',
        content: '{"important": "information"}',
      ).dummySign(nielPubkey);

      await storage.save({customData});

      final retrieved = await storage.query(
        Request<CustomData>.fromIds({customData.id}),
      );
      expect(retrieved.length, 1);

      final loaded = retrieved.first;
      expect(loaded.id, equals(customData.id));
      expect(loaded.identifier, equals('stored-data'));
      expect(loaded.content, equals('{"important": "information"}'));
    });

    test('multiple custom data events', () async {
      final data1 = PartialCustomData(
        identifier: 'data-1',
        content: 'content 1',
      ).dummySign(nielPubkey);

      final data2 = PartialCustomData(
        identifier: 'data-2',
        content: 'content 2',
      ).dummySign(nielPubkey);

      final data3 = PartialCustomData(
        identifier: 'data-3',
        content: 'content 3',
      ).dummySign(franzapPubkey);

      await storage.save({data1, data2, data3});

      // Query all
      final all = await storage.query(RequestFilter<CustomData>().toRequest());
      expect(all.length, 3);

      // Query by author
      final fromNiel = await storage.query(
        RequestFilter<CustomData>(authors: {nielPubkey}).toRequest(),
      );
      expect(fromNiel.length, 2);

      final fromFranzap = await storage.query(
        RequestFilter<CustomData>(authors: {franzapPubkey}).toRequest(),
      );
      expect(fromFranzap.length, 1);
    });

    test('query by identifier', () async {
      final data1 = PartialCustomData(
        identifier: 'user-prefs',
        content: 'theme: dark',
      ).dummySign(nielPubkey);

      final data2 = PartialCustomData(
        identifier: 'user-prefs',
        content: 'theme: light',
      ).dummySign(franzapPubkey);

      final data3 = PartialCustomData(
        identifier: 'app-config',
        content: 'version: 2.0',
      ).dummySign(nielPubkey);

      await storage.save({data1, data2, data3});

      // Query by identifier is not directly supported by filters,
      // but we can verify the data is stored correctly
      final all = await storage.query(RequestFilter<CustomData>().toRequest());
      final userPrefs = all
          .where((data) => data.identifier == 'user-prefs')
          .toList();
      expect(userPrefs.length, 2);

      final appConfig = all
          .where((data) => data.identifier == 'app-config')
          .toList();
      expect(appConfig.length, 1);
    });
  });

  group('CustomData Relationships', () {
    test('author relationship', () async {
      final profile = PartialProfile(name: 'Data Owner').dummySign(nielPubkey);
      final customData = PartialCustomData(
        identifier: 'owned-data',
        content: 'belongs to user',
      ).dummySign(nielPubkey);

      await storage.save({profile, customData});

      // Reload to ensure relationships are established
      final reloaded = await storage.query(
        Request<CustomData>.fromIds({customData.id}),
      );
      expect(reloaded.length, 1);
      expect(reloaded.first.author.value, equals(profile));
    });
  });

  group('CustomData Event Structure', () {
    test('has correct event kind and d tag', () {
      final customData = PartialCustomData(
        identifier: 'test-identifier',
        content: 'test content',
      ).dummySign(nielPubkey);

      expect(customData.event.kind, 30078);
      expect(customData.event.getFirstTagValue('d'), equals('test-identifier'));
      expect(customData.event.content, equals('test content'));
    });

    test('includes additional tags', () {
      final partial = PartialCustomData(
        identifier: 'tagged-data',
        content: 'main content',
      );

      // Add custom tags
      partial.setProperty('app', 'my-application');
      partial.setProperty('version', '1.2.3');
      partial.event.addTagValue('custom', 'value');

      final customData = partial.dummySign(nielPubkey);

      expect(customData.event.getFirstTagValue('d'), equals('tagged-data'));
      expect(
        customData.event.getFirstTagValue('app'),
        equals('my-application'),
      );
      expect(customData.event.getFirstTagValue('version'), equals('1.2.3'));
      expect(customData.event.getFirstTagValue('custom'), equals('value'));
    });

    test('shareable ID encoding', () {
      final customData = PartialCustomData(
        identifier: 'shareable-test',
        content: 'test',
      ).dummySign(nielPubkey);

      final shareableId = customData.event.shareableId;
      expect(shareableId, startsWith('naddr1'));
    });
  });

  group('CustomData Content Handling', () {
    test('handles large content', () {
      final largeContent = 'x' * 10000; // 10KB of content
      final customData = PartialCustomData(
        identifier: 'large-data',
        content: largeContent,
      ).dummySign(nielPubkey);

      expect(customData.content.length, equals(10000));
      expect(customData.content, equals(largeContent));
    });

    test('handles special characters and unicode', () {
      const unicodeContent = 'Unicode: éñüñ 🚀 🔥 中文';
      final customData = PartialCustomData(
        identifier: 'unicode-data',
        content: unicodeContent,
      ).dummySign(nielPubkey);

      expect(customData.content, equals(unicodeContent));
    });

    test('handles JSON content properly', () {
      final jsonContent = {
        'app': 'test-app',
        'config': {
          'theme': 'dark',
          'language': 'en',
          'features': ['feature1', 'feature2'],
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      final customData = PartialCustomData(
        identifier: 'json-config',
        content: jsonEncode(jsonContent),
      ).dummySign(nielPubkey);

      final parsed = jsonDecode(customData.content);
      expect(parsed['app'], equals('test-app'));
      expect(parsed['config']['theme'], equals('dark'));
      expect(parsed['config']['features'], contains('feature1'));
    });

    test('handles binary-like content', () {
      // Simulate binary data as base64
      const base64Content = 'SGVsbG8gV29ybGQ='; // "Hello World" in base64
      final customData = PartialCustomData(
        identifier: 'binary-data',
        content: base64Content,
      ).dummySign(nielPubkey);

      expect(customData.content, equals(base64Content));
    });
  });

  group('CustomData Properties API', () {
    test('setProperty and getProperty work correctly', () {
      final partial = PartialCustomData(
        identifier: 'property-test',
        content: 'main content',
      );

      // Set various properties
      partial.setProperty('string-prop', 'string-value');
      partial.setProperty('number-prop', '42');
      partial.setProperty('bool-prop', 'true');

      // Verify they can be retrieved
      expect(partial.getProperty('string-prop'), equals('string-value'));
      expect(partial.getProperty('number-prop'), equals('42'));
      expect(partial.getProperty('bool-prop'), equals('true'));
      expect(partial.getProperty('nonexistent'), isNull);

      // After signing, properties should still be accessible
      final signed = partial.dummySign(nielPubkey);
      expect(
        signed.event.getFirstTagValue('string-prop'),
        equals('string-value'),
      );
    });

    test('properties are preserved through save/load', () async {
      final partial = PartialCustomData(
        identifier: 'persistent-props',
        content: 'data',
      );

      partial.setProperty('important', 'value');
      partial.setProperty('metadata', 'info');

      final customData = partial.dummySign(nielPubkey);
      await storage.save({customData});

      final retrieved = await storage.query(
        Request<CustomData>.fromIds({customData.id}),
      );
      final loaded = retrieved.first;

      expect(loaded.event.getFirstTagValue('important'), equals('value'));
      expect(loaded.event.getFirstTagValue('metadata'), equals('info'));
    });

    test('overwrites existing properties', () {
      final partial = PartialCustomData(
        identifier: 'overwrite-test',
        content: 'content',
      );

      partial.setProperty('key', 'value1');
      expect(partial.getProperty('key'), equals('value1'));

      partial.setProperty('key', 'value2');
      expect(partial.getProperty('key'), equals('value2'));
    });
  });

  group('CustomData Error Cases', () {
    test('handles empty identifier', () {
      // Empty identifier should still work
      final customData = PartialCustomData(
        identifier: '',
        content: 'content',
      ).dummySign(nielPubkey);

      expect(customData.identifier, isEmpty);
      expect(customData.event.getFirstTagValue('d'), isEmpty);
    });

    test('identifier with special characters', () {
      const specialId = 'special:id@with/symbols';
      final customData = PartialCustomData(
        identifier: specialId,
        content: 'content',
      ).dummySign(nielPubkey);

      expect(customData.identifier, equals(specialId));
      expect(customData.event.getFirstTagValue('d'), equals(specialId));
    });
  });

  group('CustomData Use Cases', () {
    test('user preferences storage', () {
      final prefs = PartialCustomData(
        identifier: 'user-preferences',
        content: jsonEncode({
          'theme': 'dark',
          'notifications': true,
          'language': 'en',
          'fontSize': 14,
        }),
      );

      prefs.setProperty('app', 'my-app');
      prefs.setProperty('version', '2.1.0');

      final signedPrefs = prefs.dummySign(nielPubkey);
      expect(signedPrefs.identifier, equals('user-preferences'));
      expect(signedPrefs.event.getFirstTagValue('app'), equals('my-app'));
    });

    test('application configuration', () {
      final config = PartialCustomData(
        identifier: 'app-config',
        content: jsonEncode({
          'apiUrl': 'https://api.example.com',
          'timeout': 30,
          'retries': 3,
          'features': ['auth', 'notifications', 'offline'],
        }),
      );

      config.setProperty('environment', 'production');
      config.setProperty('lastUpdated', DateTime.now().toIso8601String());

      final signedConfig = config.dummySign(nielPubkey);
      expect(signedConfig.identifier, equals('app-config'));
      expect(
        signedConfig.event.getFirstTagValue('environment'),
        equals('production'),
      );
    });

    test('game save data', () {
      final saveData = PartialCustomData(
        identifier: 'game-save-1',
        content: jsonEncode({
          'level': 15,
          'score': 125000,
          'inventory': ['sword', 'shield', 'potion'],
          'position': {'x': 100, 'y': 200, 'map': 'forest'},
        }),
      );

      saveData.setProperty('game', 'adventure-quest');
      saveData.setProperty('character', 'hero');

      final signedSave = saveData.dummySign(nielPubkey);
      expect(signedSave.identifier, equals('game-save-1'));
      expect(
        signedSave.event.getFirstTagValue('game'),
        equals('adventure-quest'),
      );
    });
  });
}

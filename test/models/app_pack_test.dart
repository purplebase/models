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
        container.read(storageNotifierProvider.notifier) as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.clear();
    container.dispose();
  });

  group('AppPack', () {
    test('basic public app pack creation', () {
      const app1 =
          '32267:abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:app1';
      const app2 =
          '32267:efgh1234567890abcdef1234567890abcdef1234567890abcdef1234567890cd:app2';

      final appPack = PartialAppPack(
        name: 'Developer Tools',
        identifier: 'dev-tools',
        description: 'Essential tools for developers',
        publicApps: {app1, app2},
      ).dummySign(nielPubkey);

      expect(appPack.name, 'Developer Tools');
      expect(appPack.identifier, 'dev-tools');
      expect(
        appPack.event.getFirstTagValue('description'),
        'Essential tools for developers',
      );
      final publicApps = appPack.event
          .getTagSetValues('a')
          .where((id) => id.startsWith('32267:'))
          .toSet();
      expect(publicApps, {app1, app2});
    });

    test('event kind and structure', () {
      const testApp =
          '32267:test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:testapp';

      final appPack = PartialAppPack(
        name: 'Test Pack',
        identifier: 'test-pack',
        publicApps: {testApp},
      ).dummySign(nielPubkey);

      expect(appPack.event.kind, 30267);
      expect(appPack.event.getFirstTagValue('d'), 'test-pack');
      expect(appPack.event.getFirstTagValue('name'), 'Test Pack');

      // Check a tags for app IDs
      final aTags = appPack.event.getTagSet('a');
      expect(aTags.length, 1);
      expect(aTags.first[1], testApp);

      final publicApps = appPack.event
          .getTagSetValues('a')
          .where((id) => id.startsWith('32267:'))
          .toSet();
      expect(publicApps, {testApp});
    });

    test('partial model methods', () {
      final partial = PartialAppPack(name: 'My Apps', identifier: 'my-apps');

      // Test app management
      partial.addApp(
        '32267:test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:app1',
      );
      partial.addApp(
        '32267:test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:app2',
      );

      final publicApps1 = partial.event
          .getTagSetValues('a')
          .where((id) => id.startsWith('32267:'))
          .toSet();
      expect(publicApps1, {
        '32267:test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:app1',
        '32267:test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:app2',
      });

      partial.removeApp(
        '32267:test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:app1',
      );

      final publicApps2 = partial.event
          .getTagSetValues('a')
          .where((id) => id.startsWith('32267:'))
          .toSet();
      expect(publicApps2, {
        '32267:test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:app2',
      });
    });

    test('encrypted app pack creation with dummy signing', () {
      final partial = PartialAppPack.withEncryptedApps(
        name: 'Private Apps',
        identifier: 'private',
        description: 'My private app collection',
        apps: ['32267:pubkey123:secretapp', '32267:pubkey456:otherapp'],
      );

      // Before signing: content is plaintext, privateAppIds works
      expect(partial.privateAppIds, [
        '32267:pubkey123:secretapp',
        '32267:pubkey456:otherapp',
      ]);

      final appPack = partial.dummySign(nielPubkey);

      expect(appPack.name, 'Private Apps');
      expect(appPack.identifier, 'private');
      expect(
        appPack.event.getFirstTagValue('description'),
        'My private app collection',
      );

      // After signing: content is encrypted
      expect(appPack.content.isNotEmpty, true);
      expect(appPack.content, contains('dummy_nip44_encrypted'));

      // Public tags should be empty since apps are private
      final publicApps = appPack.event
          .getTagSetValues('a')
          .where((id) => id.startsWith('32267:'))
          .toSet();
      expect(publicApps, isEmpty);
    });

    test('app pack with encrypted private apps', () {
      final partial = PartialAppPack.withEncryptedApps(
        name: 'Private Pack',
        identifier: 'private',
        apps: ['32267:pubkey:app1', '32267:pubkey:app2'],
      );

      // Before signing: privateAppIds works
      expect(partial.privateAppIds, ['32267:pubkey:app1', '32267:pubkey:app2']);

      final appPack = partial.dummySign(nielPubkey);

      expect(appPack.name, 'Private Pack');
      // After signing: content is encrypted
      expect(appPack.content.isNotEmpty, true);
      expect(appPack.content, contains('dummy_nip44_encrypted'));
    });

    test('empty app pack', () {
      final appPack = PartialAppPack(
        name: 'Empty Pack',
        identifier: 'empty',
      ).dummySign(nielPubkey);

      expect(appPack.name, 'Empty Pack');
      final publicApps = appPack.event
          .getTagSetValues('a')
          .where((id) => id.startsWith('32267:'))
          .toSet();
      expect(publicApps, isEmpty);
      expect(appPack.event.content.isEmpty, true);
    });

    test('automatic identifier generation', () async {
      final appPack1 = PartialAppPack(name: 'Pack 1').dummySign(nielPubkey);

      // Ensure different timestamps by waiting a brief moment
      await Future.delayed(Duration(milliseconds: 1));

      final appPack2 = PartialAppPack(name: 'Pack 2').dummySign(nielPubkey);

      expect(appPack1.identifier, isNotEmpty);
      expect(appPack2.identifier, isNotEmpty);
      expect(appPack1.identifier, isNot(equals(appPack2.identifier)));
    });

    test('privateAppIds returns empty list when no content', () {
      final appPack = PartialAppPack(
        name: 'Public Only',
        identifier: 'public',
        publicApps: {
          '32267:test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:app1',
        },
      ).dummySign(nielPubkey);

      expect(appPack.privateAppIds, isEmpty);
    });

    test('privateAppIds accessible before signing', () {
      final partial = PartialAppPack.withEncryptedApps(
        name: 'Private',
        identifier: 'private',
        apps: ['32267:pubkey:secret1', '32267:pubkey:secret2'],
      );

      // Before signing: content is plaintext, privateAppIds works
      expect(partial.privateAppIds, [
        '32267:pubkey:secret1',
        '32267:pubkey:secret2',
      ]);

      // After signing: content is encrypted
      final signed = partial.dummySign(nielPubkey);
      expect(signed.content, contains('dummy_nip44_encrypted'));
    });

    test('apps relationship queries correctly', () async {
      // Create test apps
      final app1Partial = PartialApp()
        ..name = 'Test App 1'
        ..event.setTagValue('d', 'test-app-1');
      final app1 = app1Partial.dummySign(nielPubkey);

      final app2Partial = PartialApp()
        ..name = 'Test App 2'
        ..event.setTagValue('d', 'test-app-2');
      final app2 = app2Partial.dummySign(nielPubkey);

      await storage.save({app1, app2});

      // Create app pack with these apps
      final partial = PartialAppPack(
        name: 'Test Collection',
        identifier: 'test-collection',
      );

      partial.addApp(app1.id);
      partial.addApp(app2.id);

      final appPack = partial.dummySign(nielPubkey);
      await storage.save({appPack});

      // Test the apps relationship
      final packs = await storage.query(Request<AppPack>.fromIds({appPack.id}));
      expect(packs.length, 1);
      final retrievedPack = packs.first;
      expect(retrievedPack.apps.length, 2);

      final appNames = retrievedPack.apps
          .toList()
          .map((app) => app.name)
          .toSet();
      expect(appNames, {'Test App 1', 'Test App 2'});
    });

    test('linkModelById works for apps', () {
      final partial = PartialAppPack(
        name: 'Linked Apps',
        identifier: 'linked-apps',
      );

      const appId =
          '32267:abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:myapp';
      partial.linkModelById(appId, isReplaceable: true);

      final appPack = partial.dummySign(nielPubkey);

      // Check that a-tag was added
      final aTags = appPack.event.getTagSet('a');
      expect(aTags.length, 1);
      expect(aTags.first[1], appId);
    });

    test('app can find packs it belongs to', () async {
      // Create test app
      final appPartial = PartialApp()
        ..name = 'My App'
        ..event.setTagValue('d', 'my-app');
      final app = appPartial.dummySign(nielPubkey);
      await storage.save({app});

      // Create app packs that include this app
      final pack1Partial = PartialAppPack(name: 'Tools', identifier: 'tools');
      pack1Partial.addApp(app.id);
      final pack1 = pack1Partial.dummySign(nielPubkey);

      final pack2Partial = PartialAppPack(
        name: 'Favorites',
        identifier: 'favorites',
      );
      pack2Partial.addApp(app.id);
      final pack2 = pack2Partial.dummySign(nielPubkey);

      await storage.save({pack1, pack2});

      // Test the reverse relationship
      final apps = await storage.query(Request<App>.fromIds({app.id}));
      expect(apps.length, 1);
      final retrievedApp = apps.first;
      expect(retrievedApp.appPacks.length, 2);

      final packNames = retrievedApp.appPacks
          .toList()
          .map((pack) => pack.name)
          .toSet();
      expect(packNames, {'Tools', 'Favorites'});
    });

    test('storage and retrieval', () async {
      const testApp =
          '32267:test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:app1';
      final appPack = PartialAppPack(
        name: 'Saved Pack',
        identifier: 'saved-pack',
        publicApps: {testApp},
      ).dummySign(nielPubkey);

      await storage.save({appPack});

      final retrieved = await storage.query(
        Request<AppPack>.fromIds({appPack.id}),
      );

      expect(retrieved.length, 1);
      expect(retrieved.first.name, 'Saved Pack');
      expect(retrieved.first.identifier, 'saved-pack');
      final publicApps = retrieved.first.event
          .getTagSetValues('a')
          .where((id) => id.startsWith('32267:'))
          .toSet();
      expect(publicApps, {testApp});
    });

    test('replaceability - newer event replaces older', () async {
      const testApp1 =
          '32267:test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:app1';
      const testApp2 =
          '32267:test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:app2';

      final appPack1 = PartialAppPack(
        name: 'Version 1',
        identifier: 'my-apps',
        publicApps: {testApp1},
      ).dummySign(nielPubkey);

      await storage.save({appPack1});

      // Wait to ensure different timestamp
      await Future.delayed(Duration(milliseconds: 1));

      final appPack2 = PartialAppPack(
        name: 'Version 2',
        identifier: 'my-apps', // Same identifier
        publicApps: {testApp2},
      ).dummySign(nielPubkey);

      await storage.save({appPack2});

      // Query by the identifier
      final retrieved = await storage.query(
        Request<AppPack>.fromIds({appPack2.id}),
      );

      // Should only get the newer version
      expect(retrieved.length, 1);
      expect(retrieved.first.name, 'Version 2');
      final publicApps = retrieved.first.event
          .getTagSetValues('a')
          .where((id) => id.startsWith('32267:'))
          .toSet();
      expect(publicApps, {testApp2});
    });

    test('private app management with encryption and storage', () async {
      const app1 = '32267:pubkey123:privateapp1';
      const app2 = '32267:pubkey456:privateapp2';
      const app3 = '32267:pubkey789:privateapp3';

      // Create AppPack with initial private apps
      final partial = PartialAppPack(
        name: 'Private Collection',
        identifier: 'private-apps',
      );

      // Add private apps (before signing, content is plaintext)
      partial.addPrivateAppId(app1);
      partial.addPrivateAppId(app2);

      // Before signing: privateAppIds accessible
      expect(partial.privateAppIds, containsAll([app1, app2]));

      // Sign it (this encrypts the content)
      final appPack = partial.dummySign(nielPubkey);

      // After signing: content is encrypted
      expect(appPack.content.isNotEmpty, true);
      expect(appPack.content, contains('dummy_nip44_encrypted'));

      // Save to storage (stored encrypted)
      await storage.save({appPack});

      // Load from storage
      final retrieved = await storage.query(
        Request<AppPack>.fromIds({appPack.id}),
      );
      expect(retrieved.length, 1);
      final loaded = retrieved.first;

      // Content is still encrypted after loading
      expect(loaded.content, contains('dummy_nip44_encrypted'));

      // To modify: would need to decrypt first (not shown in this test)
      // For now, just create a new partial with the desired apps
      final partial2 = PartialAppPack(
        name: 'Private Collection',
        identifier: 'private-apps-v2',
      );
      partial2.addPrivateAppId(app1);
      partial2.addPrivateAppId(app2);
      partial2.addPrivateAppId(app3);
      partial2.removePrivateAppId(app1); // Remove app1

      // Before signing: verify the partial has app2 and app3
      expect(partial2.privateAppIds, containsAll([app2, app3]));
      expect(partial2.privateAppIds, isNot(contains(app1)));

      final updated = partial2.dummySign(nielPubkey);

      // After signing: content is encrypted
      expect(updated.content, contains('dummy_nip44_encrypted'));

      // Save and reload
      await storage.save({updated});
      final retrieved2 = await storage.query(
        Request<AppPack>.fromIds({updated.id}),
      );
      final reloaded = retrieved2.first;

      // Content still encrypted after reload
      expect(reloaded.content, contains('dummy_nip44_encrypted'));
    });
  });
}

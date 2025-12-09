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

  group('SocialRelayList (kind 10002)', () {
    test('basic relay list creation', () {
      final relayList = PartialSocialRelayList(
        writeRelays: {'wss://relay1.example.com'},
        readRelays: {'wss://relay2.example.com'},
        bothRelays: {'wss://relay3.example.com'},
      ).dummySign(nielPubkey);

      expect(relayList.relays.length, 3);
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
      final relayList = PartialSocialRelayList().dummySign(nielPubkey);
      expect(relayList.relays, isEmpty);
    });

    test('event kind and structure', () {
      final relayList = PartialSocialRelayList(
        readRelays: {'wss://test.relay.com'},
      ).dummySign(nielPubkey);

      expect(relayList.event.kind, 10002);
      expect(relayList.event.content, '');

      final rTags = relayList.event.getTagSet('r');
      expect(rTags.length, 1);
      expect(rTags.first[0], 'r');
      expect(rTags.first[1], 'wss://test.relay.com');
    });

    test('partial model methods', () {
      final partial = PartialSocialRelayList();

      // Test relay management
      partial.addRelay('wss://relay1.com');
      partial.addReadRelay('wss://relay2.com');
      partial.addWriteRelay('wss://relay3.com');

      expect(partial.relays.length, 3);
      expect(
        partial.relays,
        containsAll([
          'wss://relay1.com',
          'wss://relay2.com',
          'wss://relay3.com',
        ]),
      );

      partial.removeRelay('wss://relay1.com');
      expect(partial.relays.length, 2);
      expect(partial.relays.contains('wss://relay1.com'), false);
    });

    test('save and query relay list', () async {
      final relayList = PartialSocialRelayList(
        bothRelays: {'wss://stored.relay.com'},
      ).dummySign(nielPubkey);

      await storage.save({relayList});

      final retrieved = await storage.query(
        RequestFilter<SocialRelayList>(
          authors: {nielPubkey},
        ).toRequest(),
      );

      expect(retrieved, hasLength(1));
      expect(retrieved.first.relays, contains('wss://stored.relay.com'));
    });
  });

  group('AppCatalogRelayList (kind 10067)', () {
    test('basic relay list creation', () {
      final relayList = PartialAppCatalogRelayList(
        relays: {
          'wss://relay.zapstore.dev',
          'wss://relay.nostr.band',
        },
      ).dummySign(nielPubkey);

      expect(relayList.relays, hasLength(2));
      expect(relayList.relays, contains('wss://relay.zapstore.dev'));
      expect(relayList.relays, contains('wss://relay.nostr.band'));
      expect(relayList.hasRelays, isTrue);
    });

    test('relay list with no relays', () {
      final relayList = PartialAppCatalogRelayList().dummySign(nielPubkey);

      expect(relayList.relays, isEmpty);
      expect(relayList.hasRelays, isFalse);
    });

    test('event kind and structure', () {
      final relayList = PartialAppCatalogRelayList(
        relays: {'wss://test.relay.com'},
      ).dummySign(nielPubkey);

      expect(relayList.event.kind, 10067);
      expect(relayList.event.content, '');
      expect(relayList.event.getTagSetValues('r'), contains('wss://test.relay.com'));
    });

    test('partial model add/remove relay', () {
      final partial = PartialAppCatalogRelayList();

      // Add relays
      partial.addRelay('wss://relay1.com');
      partial.addRelay('wss://relay2.com');

      expect(partial.relays, hasLength(2));
      expect(partial.relays, contains('wss://relay1.com'));
      expect(partial.relays, contains('wss://relay2.com'));

      // Remove a relay
      partial.removeRelay('wss://relay1.com');
      expect(partial.relays, hasLength(1));
      expect(partial.relays, contains('wss://relay2.com'));
      expect(partial.relays.contains('wss://relay1.com'), isFalse);
    });

    test('save and query relay list', () async {
      final relayList = PartialAppCatalogRelayList(
        relays: {'wss://stored.relay.com'},
      ).dummySign(nielPubkey);

      await storage.save({relayList});

      // Query by kind
      final retrieved = await storage.query(
        RequestFilter<AppCatalogRelayList>(
          authors: {nielPubkey},
        ).toRequest(),
      );

      expect(retrieved, hasLength(1));
      expect(retrieved.first.relays, contains('wss://stored.relay.com'));
    });
  });

  group('RelayList.labels registry', () {
    test('labels contains AppCatalog mapping', () {
      expect(RelayList.labels, containsPair('AppCatalog', 10067));
    });

    test('labels can be extended for future relay list types', () {
      // This test documents that labels is a const map
      // New relay list types should be added to the static const
      expect(RelayList.labels, isA<Map<String, int>>());
    });
  });

  group('StorageConfiguration.defaultRelays with labels', () {
    test('defaultRelays are used as fallback', () async {
      final config = StorageConfiguration(
        defaultRelays: {
          'AppCatalog': {'wss://relay.zapstore.dev'},
        },
      );

      // Query using label should resolve to default relays
      final resolvedRelays = config.getRelays(
        source: RemoteSource(relays: 'AppCatalog'),
      );
      expect(resolvedRelays, contains('wss://relay.zapstore.dev'));
    });

    test('ad-hoc relay URL bypasses lookup', () {
      final config = StorageConfiguration(
        defaultRelays: {
          'AppCatalog': {'wss://relay.zapstore.dev'},
        },
      );

      // Ad-hoc URL should be used directly
      final resolvedRelays = config.getRelays(
        source: RemoteSource(relays: 'wss://custom.relay.com'),
      );
      expect(resolvedRelays, equals({'wss://custom.relay.com'}));
    });

    test('unknown label returns empty set', () {
      final config = StorageConfiguration(
        defaultRelays: {
          'AppCatalog': {'wss://relay.zapstore.dev'},
        },
      );

      final resolvedRelays = config.getRelays(
        source: RemoteSource(relays: 'NonExistent'),
      );
      expect(resolvedRelays, isEmpty);
    });

    test('null relays returns empty set (TODO: outbox lookup)', () {
      final config = StorageConfiguration(
        defaultRelays: {
          'AppCatalog': {'wss://relay.zapstore.dev'},
        },
      );

      // Null relays should return empty (future: outbox lookup)
      final resolvedRelays = config.getRelays(source: RemoteSource());
      expect(resolvedRelays, isEmpty);
    });
  });

  group('StorageNotifier.resolveRelays() - Signed RelayList precedence', () {
    test('uses defaultRelays when no signed RelayList exists', () async {
      final testContainer = await createTestContainer(
        config: StorageConfiguration(
          keepSignatures: false,
          defaultRelays: {
            'AppCatalog': {'wss://default1.com', 'wss://default2.com'},
          },
        ),
      );
      final testStorage = testContainer.read(storageNotifierProvider.notifier)
          as DummyStorageNotifier;

      final resolved = await testStorage.resolveRelays('AppCatalog');

      expect(resolved, hasLength(2));
      expect(resolved, contains('wss://default1.com'));
      expect(resolved, contains('wss://default2.com'));

      testContainer.dispose();
    });

    test('signed AppCatalogRelayList overrides defaultRelays', () async {
      final testContainer = await createTestContainer(
        config: StorageConfiguration(
          keepSignatures: false,
          defaultRelays: {
            'AppCatalog': {'wss://default1.com', 'wss://default2.com'},
          },
        ),
      );
      final testStorage = testContainer.read(storageNotifierProvider.notifier)
          as DummyStorageNotifier;
      final testRef = testContainer.read(refProvider);

      // Create and sign in a test signer
      final testSigner = Bip340PrivateKeySigner(
        'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8',
        testRef,
      );
      await testSigner.signIn();
      testSigner.setAsActivePubkey();

      // Save a signed AppCatalogRelayList for the active user
      final signedRelayList = PartialAppCatalogRelayList(
        relays: {'wss://signed1.com', 'wss://signed2.com', 'wss://signed3.com'},
      ).dummySign(testSigner.pubkey);

      await testStorage.save({signedRelayList});

      // Resolve should now return signed relays, not defaults
      final resolved = await testStorage.resolveRelays('AppCatalog');

      expect(resolved, hasLength(3));
      expect(resolved, contains('wss://signed1.com'));
      expect(resolved, contains('wss://signed2.com'));
      expect(resolved, contains('wss://signed3.com'));
      expect(resolved, isNot(contains('wss://default1.com')));
      expect(resolved, isNot(contains('wss://default2.com')));

      testContainer.dispose();
    });

    test('ad-hoc relay URL bypasses both defaults and signed', () async {
      final testContainer = await createTestContainer(
        config: StorageConfiguration(
          keepSignatures: false,
          defaultRelays: {
            'AppCatalog': {'wss://default.com'},
          },
        ),
      );
      final testStorage = testContainer.read(storageNotifierProvider.notifier)
          as DummyStorageNotifier;
      final testRef = testContainer.read(refProvider);

      // Create and sign in a test signer
      final testSigner = Bip340PrivateKeySigner(
        'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8',
        testRef,
      );
      await testSigner.signIn();
      testSigner.setAsActivePubkey();

      // Save signed RelayList
      final signedRelayList = PartialAppCatalogRelayList(
        relays: {'wss://signed.com'},
      ).dummySign(testSigner.pubkey);

      await testStorage.save({signedRelayList});

      // Ad-hoc URL should bypass everything
      final resolved = await testStorage.resolveRelays('wss://adhoc.relay.com');

      expect(resolved, equals({'wss://adhoc.relay.com'}));

      testContainer.dispose();
    });

    test('null identifier returns empty set (TODO: outbox lookup)', () async {
      final testContainer = await createTestContainer(
        config: StorageConfiguration(keepSignatures: false),
      );
      final testStorage = testContainer.read(storageNotifierProvider.notifier)
          as DummyStorageNotifier;

      final resolved = await testStorage.resolveRelays(null);
      expect(resolved, isEmpty);

      testContainer.dispose();
    });

    test('unknown label with no defaults returns empty set', () async {
      final testContainer = await createTestContainer(
        config: StorageConfiguration(keepSignatures: false),
      );
      final testStorage = testContainer.read(storageNotifierProvider.notifier)
          as DummyStorageNotifier;

      final resolved = await testStorage.resolveRelays('UnknownLabel');
      expect(resolved, isEmpty);

      testContainer.dispose();
    });

    test('publish() uses resolveRelays for relay resolution', () async {
      final testContainer = await createTestContainer(
        config: StorageConfiguration(
          keepSignatures: false,
          defaultRelays: {
            'AppCatalog': {'wss://default.com'},
          },
        ),
      );
      final testStorage = testContainer.read(storageNotifierProvider.notifier)
          as DummyStorageNotifier;
      final testRef = testContainer.read(refProvider);

      // Create and sign in a test signer
      final testSigner = Bip340PrivateKeySigner(
        'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8',
        testRef,
      );
      await testSigner.signIn();
      testSigner.setAsActivePubkey();

      // Save signed AppCatalogRelayList
      final signedRelayList = PartialAppCatalogRelayList(
        relays: {'wss://signed.com'},
      ).dummySign(testSigner.pubkey);
      await testStorage.save({signedRelayList});

      // Publish a note using the 'AppCatalog' label
      final note = PartialNote('Test note').dummySign(testSigner.pubkey);
      final response = await testStorage.publish(
        {note},
        source: RemoteSource(relays: 'AppCatalog'),
      );

      // Should have published to the signed relay, not the default
      expect(response.results, isNotEmpty);
      // Get all relay URLs from the results
      final allRelayUrls = response.results.values
          .expand((states) => states.map((s) => s.relayUrl))
          .toSet();
      expect(allRelayUrls, contains('wss://signed.com'));
      expect(allRelayUrls, isNot(contains('wss://default.com')));

      testContainer.dispose();
    });
  });
}


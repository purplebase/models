import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
    ref = container.read(refProvider);
    storage =
        container.read(storageNotifierProvider.notifier) as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.clear();
    container.dispose();
  });

  group('TargetedPublication', () {
    test('targeted publication creation and serialization', () async {
      // Create related models first
      final authorProfile = PartialProfile(
        name: 'Community Creator',
      ).dummySign(nielPubkey);
      await storage.save({authorProfile});

      final community = PartialCommunity(
        name: 'Test Community',
        relayUrls: {'wss://test.relay'},
        description: 'A community for testing',
      ).dummySign(nielPubkey);

      final note = PartialNote('Test content').dummySign();
      await storage.save({community, note});

      // Test the main constructor
      final targetedPublication = PartialTargetedPublication(
        note,
        communities: {community},
        relayUrls: {'wss://distribute.relay'},
        identifier: 'test-identifier',
      ).dummySign();

      await storage.save({targetedPublication});

      // Test properties and relationships
      expect(targetedPublication.targetedKind, 1); // Note kind
      expect(
        targetedPublication.communityPubkeys,
        contains(community.event.pubkey),
      );
      expect(targetedPublication.relayUrls, contains('wss://distribute.relay'));
      expect(targetedPublication.model.value, note);
      expect(targetedPublication.communities.toList(), [community]);

      // Test serialization roundtrip
      final targetedPublication2 = TargetedPublication.fromMap(
        targetedPublication.toMap(),
        ref,
      );
      expect(targetedPublication.toMap(), targetedPublication2.toMap());
    });

    test('forExistingEvent constructor', () async {
      // Create related models first
      final authorProfile = PartialProfile(
        name: 'Community Creator',
      ).dummySign(nielPubkey);
      await storage.save({authorProfile});

      final community = PartialCommunity(
        name: 'Test Community',
        relayUrls: {'wss://test.relay'},
        description: 'A community for testing',
      ).dummySign(nielPubkey);

      final note = PartialNote('Test content').dummySign();
      await storage.save({community, note});

      // Test the forExistingEvent constructor
      final targetedPublication = PartialTargetedPublication.forExistingEvent(
        note.id,
        note.event.kind,
        communities: {community},
        relayUrls: {'wss://distribute.relay'},
        identifier: 'existing-event-identifier',
      ).dummySign();

      await storage.save({targetedPublication});

      // Test properties
      expect(targetedPublication.targetedKind, 1); // Note kind
      expect(
        targetedPublication.communityPubkeys,
        contains(community.event.pubkey),
      );
      expect(targetedPublication.relayUrls, contains('wss://distribute.relay'));

      // Test that it references the existing event
      expect(targetedPublication.event.containsTag('e'), isTrue);
      expect(targetedPublication.event.getFirstTagValue('e'), note.id);
      expect(
        targetedPublication.event.containsTag('a'),
        isFalse,
      ); // Should not have 'a' tag
    });

    test('targeted publication with multiple communities', () async {
      // Create multiple communities with different pubkeys
      final community1 = PartialCommunity(
        name: 'Community 1',
        relayUrls: {'wss://relay1.com'},
      ).dummySign(nielPubkey);

      final community2 =
          PartialCommunity(
            name: 'Community 2',
            relayUrls: {'wss://relay2.com'},
          ).dummySign(
            'b9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885bf',
          );

      final note = PartialNote('Multi-community content').dummySign();
      await storage.save({community1, community2, note});

      final targetedPublication = PartialTargetedPublication(
        note,
        communities: {community1, community2},
        relayUrls: {'wss://distribute.relay'},
      ).dummySign();

      await storage.save({targetedPublication});

      // Test that it targets both communities
      expect(targetedPublication.communityPubkeys, hasLength(2));
      expect(
        targetedPublication.communityPubkeys,
        contains(community1.event.pubkey),
      );
      expect(
        targetedPublication.communityPubkeys,
        contains(community2.event.pubkey),
      );
      expect(targetedPublication.communities.toList(), hasLength(2));
    });

    test('targeted publication with custom identifier', () async {
      final community = PartialCommunity(
        name: 'Test Community',
        relayUrls: {'wss://test.relay'},
      ).dummySign(nielPubkey);

      final note = PartialNote('Test content').dummySign();
      await storage.save({community, note});

      final customIdentifier = 'custom-identifier-123';
      final targetedPublication = PartialTargetedPublication(
        note,
        communities: {community},
        identifier: customIdentifier,
      ).dummySign();

      await storage.save({targetedPublication});

      // Test that the custom identifier is used
      expect(targetedPublication.event.identifier, customIdentifier);
    });

    test(
      'targeted publication without identifier generates random one',
      () async {
        final community = PartialCommunity(
          name: 'Test Community',
          relayUrls: {'wss://test.relay'},
        ).dummySign(nielPubkey);

        final note = PartialNote('Test content').dummySign();
        await storage.save({community, note});

        final targetedPublication = PartialTargetedPublication(
          note,
          communities: {community},
        ).dummySign();

        await storage.save({targetedPublication});

        // Test that a random identifier is generated
        expect(targetedPublication.event.identifier, hasLength(64));
        expect(
          targetedPublication.event.identifier,
          matches(RegExp(r'^[0-9a-f]{64}$')),
        );
      },
    );

    test('targeted publication relationships work correctly', () async {
      final community = PartialCommunity(
        name: 'Test Community',
        relayUrls: {'wss://test.relay'},
      ).dummySign(nielPubkey);

      final note = PartialNote('Test content').dummySign();
      await storage.save({community, note});

      final targetedPublication = PartialTargetedPublication(
        note,
        communities: {community},
      ).dummySign();

      await storage.save({targetedPublication});

      // Test that relationships are properly established
      final loadedPublication = TargetedPublication.fromMap(
        targetedPublication.toMap(),
        ref,
      );

      // Test model relationship
      expect(loadedPublication.model.value, note);

      // Test communities relationship
      final communities = loadedPublication.communities.toList();
      expect(communities, hasLength(1));
      expect(communities.first, community);
    });
  });
}

import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:models/models.dart';
import '../helpers.dart';

/// Test to verify if StorageState equality properly detects
/// when replaceable models are updated (new content, different event.id)
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

  group('Replaceable Model Equality Tests', () {
    test('Model equality: same addressable ID but different event.id should be unequal', () {
      final signedPack1 = PartialAppStack(
        name: 'Original Name',
        identifier: 'test-pack',
      ).dummySign(storage, nielPubkey);

      final signedPack2 = PartialAppStack(
        name: 'Updated Name',
        identifier: 'test-pack',
      ).dummySign(storage, nielPubkey);

      expect(signedPack1.id, equals(signedPack2.id),
          reason: 'Should have same addressable ID');

      expect(signedPack1.event.id, isNot(equals(signedPack2.event.id)),
          reason: 'Should have different event IDs (different content)');

      expect(signedPack1, isNot(equals(signedPack2)),
          reason: 'Models should NOT be equal (different event.id)');
    });

    test('StorageData equality: updated replaceable model should trigger change', () {
      final signedPack1 = PartialAppStack(
        name: 'Original Name',
        identifier: 'test-pack',
      ).dummySign(storage, nielPubkey);

      final signedPack2 = PartialAppStack(
        name: 'Updated Name',
        identifier: 'test-pack',
      ).dummySign(storage, nielPubkey);

      final state1 = StorageData<AppStack>([signedPack1]);
      final state2 = StorageData<AppStack>([signedPack2]);

      expect(state1, isNot(equals(state2)),
          reason: 'StorageData should NOT be equal when model event.id differs');
    });

    test('Riverpod listener detection: updated replaceable model should notify', () async {
      final signedPack1 = PartialAppStack(
        name: 'Original Name',
        identifier: 'test-pack',
      ).dummySign(storage, nielPubkey);

      await storage.save({signedPack1});

      final queryProvider = query<AppStack>(
        ids: {signedPack1.id},
        source: const LocalAndRemoteSource(stream: false),
      );

      int notificationCount = 0;
      List<List<String>> capturedNames = [];

      container.listen<StorageState<AppStack>>(
        queryProvider,
        (previous, next) {
          notificationCount++;
          capturedNames.add(next.models.map((m) => m.name ?? '').toList());
        },
        fireImmediately: false,
      );

      await pumpEventQueue();

      final signedPack2 = PartialAppStack(
        name: 'Updated Name',
        identifier: 'test-pack',
      ).dummySign(storage, nielPubkey);

      await storage.save({signedPack2});

      await pumpEventQueue();

      final updatedState = container.read(queryProvider);

      expect(notificationCount, greaterThanOrEqualTo(1),
          reason: 'Listener should fire when replaceable model is updated');

      if (capturedNames.isNotEmpty) {
        expect(capturedNames.last, contains('Updated Name'),
            reason: 'Should have captured the updated name');
      }
    });
  });
}

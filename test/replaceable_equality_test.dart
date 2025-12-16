import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:models/models.dart';
import 'helpers.dart';

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
      // Create first version of AppPack
      final signedPack1 = PartialAppPack(
        name: 'Original Name',
        identifier: 'test-pack',
      ).dummySign(nielPubkey);
      
      // Wait to ensure different timestamp
      Future.delayed(Duration(milliseconds: 1));
      
      // Create second version with same identifier but different content
      final signedPack2 = PartialAppPack(
        name: 'Updated Name',
        identifier: 'test-pack',
      ).dummySign(nielPubkey);

      // Verify models have same addressable ID
      expect(signedPack1.id, equals(signedPack2.id),
          reason: 'Should have same addressable ID');

      // Verify models have different event IDs
      expect(signedPack1.event.id, isNot(equals(signedPack2.event.id)),
          reason: 'Should have different event IDs (different signatures)');

      // Verify Model equality compares by event.id
      expect(signedPack1, isNot(equals(signedPack2)),
          reason: 'Models should NOT be equal (different event.id)');
    });

    test('StorageData equality: updated replaceable model should trigger change', () {
      // Create first version of AppPack
      final signedPack1 = PartialAppPack(
        name: 'Original Name',
        identifier: 'test-pack',
      ).dummySign(nielPubkey);
      
      // Wait to ensure different timestamp
      Future.delayed(Duration(milliseconds: 1));
      
      // Create second version with same identifier but different content
      final signedPack2 = PartialAppPack(
        name: 'Updated Name',
        identifier: 'test-pack',
      ).dummySign(nielPubkey);

      // Create two StorageData states
      final state1 = StorageData<AppPack>([signedPack1]);
      final state2 = StorageData<AppPack>([signedPack2]);

      print('State 1 models: ${state1.models.map((m) => m.event.id).toList()}');
      print('State 2 models: ${state2.models.map((m) => m.event.id).toList()}');
      print('State 1 props: ${state1.props}');
      print('State 2 props: ${state2.props}');
      print('Models equal: ${state1.models[0] == state2.models[0]}');
      print('States equal: ${state1 == state2}');
      print('States identical: ${identical(state1, state2)}');

      // THIS IS THE BUG: States should NOT be equal because the models are different
      expect(state1, isNot(equals(state2)),
          reason: 'StorageData should NOT be equal when model event.id differs');
    });

    test('Riverpod listener detection: updated replaceable model should notify', () async {
      // Create and save first version
      final signedPack1 = PartialAppPack(
        name: 'Original Name',
        identifier: 'test-pack',
      ).dummySign(nielPubkey);
      
      await storage.save({signedPack1});

      // Create query provider
      final queryProvider = query<AppPack>(
        ids: {signedPack1.id},
        source: const LocalAndRemoteSource(stream: false),
      );

      // Listen to changes
      int notificationCount = 0;
      List<List<String>> capturedNames = [];
      
      container.listen<StorageState<AppPack>>(
        queryProvider,
        (previous, next) {
          notificationCount++;
          print('Notification #$notificationCount:');
          print('  Previous: ${previous?.models.map((m) => m.name).toList()}');
          print('  Next: ${next.models.map((m) => m.name).toList()}');
          print('  Previous == Next: ${previous == next}');
          print('  Models[0] event.id: ${next.models.firstOrNull?.event.id}');
          capturedNames.add(next.models.map((m) => m.name ?? '').toList());
        },
        fireImmediately: false,
      );

      // Wait for initial query to complete
      await Future.delayed(Duration(milliseconds: 100));
      
      final initialState = container.read(queryProvider);
      print('Initial state: ${initialState.models.map((m) => m.name).toList()}');
      
      // Update the pack with new content
      final signedPack2 = PartialAppPack(
        name: 'Updated Name',
        identifier: 'test-pack',
      ).dummySign(nielPubkey);
      
      print('Saving updated pack with event.id: ${signedPack2.event.id}');
      await storage.save({signedPack2});

      // Wait for update to propagate
      await Future.delayed(Duration(milliseconds: 200));

      final updatedState = container.read(queryProvider);
      print('Updated state: ${updatedState.models.map((m) => m.name).toList()}');
      print('Updated state models[0] event.id: ${updatedState.models.firstOrNull?.event.id}');

      print('\nTotal notifications: $notificationCount');
      print('Captured names: $capturedNames');

      // THIS IS WHAT WE'RE TESTING:
      // The listener should fire when the replaceable model is updated
      expect(notificationCount, greaterThanOrEqualTo(1),
          reason: 'Listener should fire when replaceable model is updated');
      
      if (capturedNames.isNotEmpty) {
        expect(capturedNames.last, contains('Updated Name'),
            reason: 'Should have captured the updated name');
      }
    });
  });
}


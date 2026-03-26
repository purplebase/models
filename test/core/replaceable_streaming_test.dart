import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:models/models.dart';
import '../helpers.dart';

/// Test to verify if replaceable models update correctly when received
/// through streaming relay subscriptions (the actual bug scenario)
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

  group('Replaceable Model Streaming Updates', () {
    test(
      'query provider should update when replaceable model is updated via relay',
      () async {
        // Create and publish initial version
        final pack1 = PartialAppStack(
          name: 'Version 1',
          identifier: 'streaming-pack',
        ).dummySign(nielPubkey);

        // Save to storage (simulates receiving from network)
        await storage.save({pack1});

        // Set up query with streaming enabled
        final queryProvider = query<AppStack>(
          authors: {nielPubkey},
          source: const LocalAndRemoteSource(stream: true),
        );

        final tester = container.testerFor(queryProvider);

        // Expect initial state (StorageLoading until EOSE for LocalAndRemoteSource)
        await tester.expectModels(hasLength(1));
        expect(
          (tester.notifier.state.models.first as AppStack).name,
          'Version 1',
        );

        // Now publish an UPDATE with same identifier but different content
        final pack2 = PartialAppStack(
          name: 'Version 2 - Updated',
          identifier: 'streaming-pack', // Same identifier!
        ).dummySign(nielPubkey);

        // Save update to storage
        await storage.save({pack2});

        // Verify the final state has the updated version
        // The tester will wait for the next state emission
        await tester.expectModels(
          allOf(
            hasLength(1),
            everyElement((m) => m.name == 'Version 2 - Updated'),
          ),
        );

        final state2 = container.read(queryProvider);
        expect(
          state2.models.first.event.id,
          equals(pack2.event.id),
          reason: 'Should have the new event ID',
        );
      },
    );

    test('verify storage properly replaces old events', () async {
      // Create initial version
      final pack1 = PartialAppStack(
        name: 'Initial',
        identifier: 'test-pack',
      ).dummySign(nielPubkey);

      // Save initial version
      await storage.save({pack1});

      final req = Request<AppStack>([
        RequestFilter<AppStack>(authors: {nielPubkey}),
      ]);
      final results1 = storage.querySync(req);

      expect(results1, hasLength(1));

      // Now save update
      final pack2 = PartialAppStack(
        name: 'Updated',
        identifier: 'test-pack', // Same identifier
      ).dummySign(nielPubkey);

      await storage.save({pack2});

      final results2 = storage.querySync(req);

      // The storage should have replaced the old event
      expect(
        results2,
        hasLength(1),
        reason: 'Should still have 1 event (replaced, not added)',
      );

      expect(
        results2.first.name,
        equals('Updated'),
        reason: 'Should have the updated name',
      );
    });
  });
}

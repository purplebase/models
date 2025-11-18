import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:models/models.dart';
import 'helpers.dart';

/// Test to verify if replaceable models update correctly when received
/// through streaming relay subscriptions (the actual bug scenario)
void main() {
  late ProviderContainer container;
  late DummyStorageNotifier storage;
  late NostrRelay relay;

  setUp(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    storage =
        container.read(storageNotifierProvider.notifier)
            as DummyStorageNotifier;
    relay = container.read(relayProvider);
  });

  tearDown(() async {
    await storage.cancel();
    await storage.clear();
    container.dispose();
  });

  group('Replaceable Model Streaming Updates', () {
    test(
      'query provider should update when replaceable model is updated via relay',
      () async {
        // Create and publish initial version
        final pack1 = PartialAppPack(
          name: 'Version 1',
          identifier: 'streaming-pack',
        ).dummySign(nielPubkey);

        // Publish to relay (simulates receiving from network)
        relay.publish([pack1.toMap()]);

        // Set up query with streaming enabled
        final queryProvider = query<AppPack>(
          authors: {nielPubkey},
          source: const LocalAndRemoteSource(stream: true, background: false),
        );

        // Track state changes
        int notificationCount = 0;
        List<String> capturedNames = [];
        List<String> capturedEventIds = [];

        container.listen<StorageState<AppPack>>(queryProvider, (
          previous,
          next,
        ) {
          notificationCount++;
          final name = next.models.firstOrNull?.name ?? 'none';
          final eventId = next.models.firstOrNull?.event.id ?? 'none';

          print('Notification #$notificationCount:');
          print('  Name: $name');
          print('  Event ID: $eventId');
          print(
            '  Previous: ${previous?.models.map((m) => '${m.name} (${m.event.id.substring(0, 8)})').toList()}',
          );
          print(
            '  Next: ${next.models.map((m) => '${m.name} (${m.event.id.substring(0, 8)})').toList()}',
          );
          print('  Previous == Next: ${previous == next}');
          print(
            '  Previous?.props: ${previous?.props.map((p) => p is List ? '${p.length} items' : p)}',
          );
          print(
            '  Next.props: ${next.props.map((p) => p is List ? '${p.length} items' : p)}',
          );

          capturedNames.add(name);
          capturedEventIds.add(eventId);
        }, fireImmediately: false);

        // Wait for initial query and EOSE
        await Future.delayed(Duration(milliseconds: 150));

        final state1 = container.read(queryProvider);
        print('\n=== After initial load ===');
        print('State: ${state1.models.map((m) => m.name).toList()}');
        print(
          'Event IDs: ${state1.models.map((m) => m.event.id.substring(0, 8)).toList()}',
        );

        // Now publish an UPDATE with same identifier but different content
        await Future.delayed(Duration(milliseconds: 10));

        final pack2 = PartialAppPack(
          name: 'Version 2 - Updated',
          identifier: 'streaming-pack', // Same identifier!
        ).dummySign(nielPubkey);

        print('\n=== Publishing update ===');
        print('Old event ID: ${pack1.event.id.substring(0, 8)}');
        print('New event ID: ${pack2.event.id.substring(0, 8)}');
        print('Same addressable ID: ${pack1.id == pack2.id}');
        print('Same event ID: ${pack1.event.id == pack2.event.id}');

        // Publish update to relay
        relay.publish([pack2.toMap()]);

        // Wait for streaming update to propagate
        await Future.delayed(Duration(milliseconds: 150));

        final state2 = container.read(queryProvider);
        print('\n=== After update ===');
        print('State: ${state2.models.map((m) => m.name).toList()}');
        print(
          'Event IDs: ${state2.models.map((m) => m.event.id.substring(0, 8)).toList()}',
        );

        print('\n=== Summary ===');
        print('Total notifications: $notificationCount');
        print('Captured names: $capturedNames');
        print(
          'Captured event IDs: ${capturedEventIds.map((id) => id.substring(0, 8)).toList()}',
        );

        // Verify we got at least 2 notifications (initial + update)
        expect(
          notificationCount,
          greaterThanOrEqualTo(2),
          reason: 'Should get notification for initial load and update',
        );

        // Verify the final state has the updated version
        expect(
          state2.models,
          hasLength(1),
          reason: 'Should have exactly 1 model (replaced, not added)',
        );
        expect(
          state2.models.first.name,
          equals('Version 2 - Updated'),
          reason: 'Should have the updated name',
        );
        expect(
          state2.models.first.event.id,
          equals(pack2.event.id),
          reason: 'Should have the new event ID',
        );

        // Verify we captured the update
        expect(
          capturedNames,
          contains('Version 2 - Updated'),
          reason: 'Should have captured the updated name in notifications',
        );
      },
    );

    test('verify relay subscription properly replaces old events', () async {
      // Create initial version
      final pack1 = PartialAppPack(
        name: 'Initial',
        identifier: 'test-pack',
      ).dummySign(nielPubkey);

      // Get relay subscription directly
      final req = Request<AppPack>([
        RequestFilter<AppPack>(authors: {nielPubkey}),
      ]);
      final subProvider = relaySubscriptionProvider(req);

      // Publish initial version
      relay.publish([pack1.toMap()]);

      await Future.delayed(Duration(milliseconds: 50));

      final state1 = container.read(subProvider);
      print('\n=== Initial relay subscription state ===');
      print('Events: ${state1.events.length}');
      print(
        'Names: ${state1.events.map((e) => e['tags'].firstWhere((t) => t[0] == 'name', orElse: () => ['', 'none'])[1]).toList()}',
      );
      print(
        'Event IDs: ${state1.events.map((e) => (e['id'] as String).substring(0, 8)).toList()}',
      );

      expect(state1.events, hasLength(1));

      // Now publish update
      await Future.delayed(Duration(milliseconds: 10));

      final pack2 = PartialAppPack(
        name: 'Updated',
        identifier: 'test-pack', // Same identifier
      ).dummySign(nielPubkey);

      relay.publish([pack2.toMap()]);

      await Future.delayed(Duration(milliseconds: 50));

      final state2 = container.read(subProvider);
      print('\n=== After update relay subscription state ===');
      print('Events: ${state2.events.length}');
      print(
        'Names: ${state2.events.map((e) => e['tags'].firstWhere((t) => t[0] == 'name', orElse: () => ['', 'none'])[1]).toList()}',
      );
      print(
        'Event IDs: ${state2.events.map((e) => (e['id'] as String).substring(0, 8)).toList()}',
      );

      // The relay subscription should have replaced the old event
      expect(
        state2.events,
        hasLength(1),
        reason: 'Should still have 1 event (replaced, not added)',
      );

      final finalName = state2.events.first['tags'].firstWhere(
        (t) => t[0] == 'name',
        orElse: () => ['', 'none'],
      )[1];
      expect(
        finalName,
        equals('Updated'),
        reason: 'Should have the updated name',
      );
    });
  });
}

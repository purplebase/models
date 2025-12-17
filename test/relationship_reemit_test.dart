import 'dart:async';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Tests that relationship data arriving triggers re-emission of main query results,
/// even when the main results haven't changed (so listeners can check relationships).
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
    container.dispose();
  });

  group('Relationship re-emission', () {
    test(
      'main query re-emits when relationship data arrives (stream: false)',
      () async {
        final pubkey = franzapPubkey;

        // Create a Release that will be the relationship target
        final partialRelease = PartialRelease()
          ..identifier = 'com.example.reemit@1.0.0';
        partialRelease.event.addTag('i', ['com.example.reemit']);
        partialRelease.event.addTag('version', ['1.0.0']);
        final release = partialRelease.dummySign(pubkey);

        // Create an App
        final partialApp = PartialApp()
          ..identifier = 'com.example.reemit'
          ..description = 'Test re-emission';
        final app = partialApp.dummySign(pubkey);

        // Save the App first
        await storage.save({app});

        // Track all emissions
        final emissions = <StorageState<App>>[];
        var emissionCount = 0;

        // Watch using stream: false for relationships
        final provider = model<App>(
          app,
          and: (a) => {a.latestRelease},
          source: LocalAndRemoteSource(stream: true),
          andSource: LocalAndRemoteSource(
            stream: false,
          ), // Non-streaming relationship
        );

        // Listen to state changes
        final sub = container.listen(provider, (_, state) {
          if (state is StorageData<App>) {
            emissionCount++;
            emissions.add(state);
          }
        });

        // Initial read
        container.read(provider);
        await Future.delayed(const Duration(milliseconds: 50));

        final initialEmissions = emissionCount;

        // Verify initial state: app exists, no release yet
        expect(emissions.last.models, hasLength(1));
        expect(
          emissions.last.models.first.latestRelease.value,
          isNull,
          reason: 'Release not saved yet',
        );

        // Now save the Release - this should trigger re-emission
        await storage.save({release});
        await Future.delayed(const Duration(milliseconds: 100));

        // BUG CHECK: Did we get a re-emission?
        expect(
          emissionCount,
          greaterThan(initialEmissions),
          reason: 'Main query should re-emit when relationship data arrives',
        );

        // And the relationship should be loaded now
        final latestRelease = emissions.last.models.first.latestRelease.value;
        expect(
          latestRelease,
          isNotNull,
          reason: 'latestRelease.value should be populated after re-emission',
        );

        sub.close();
      },
    );

    test(
      'verifies subscription is registered for relationship requests',
      () async {
        final pubkey = franzapPubkey;

        // Create app
        final partialApp = PartialApp()
          ..identifier = 'com.example.sub'
          ..description = 'Test subscription';
        final app = partialApp.dummySign(pubkey);

        await storage.save({app});

        // Start watching with relationships
        final provider = model<App>(
          app,
          and: (a) => {a.latestRelease},
          source: LocalAndRemoteSource(stream: true),
          // andSource defaults to source (stream: true)
        );

        // Keep provider alive with a listener (autoDispose provider!)
        final sub = container.listen(provider, (_, __) {});

        await Future.delayed(const Duration(milliseconds: 50));

        // Check that the notifier has registered the merged relationship request
        final notifier = container.read(provider.notifier);

        expect(
          notifier.mergedRelationshipRequests,
          isNotEmpty,
          reason: 'Relationship requests should be tracked',
        );

        sub.close();
      },
    );

    test(
      'zapstore scenario: source=LocalSource triggers relationship queries via andSource',
      () async {
        final pubkey = franzapPubkey;

        // Create release
        final partialRelease = PartialRelease()
          ..identifier = 'com.example.zapstore@1.0.0';
        partialRelease.event.addTag('i', ['com.example.zapstore']);
        partialRelease.event.addTag('version', ['1.0.0']);
        final release = partialRelease.dummySign(pubkey);

        // Create app
        final partialApp = PartialApp()
          ..identifier = 'com.example.zapstore'
          ..description = 'Zapstore scenario';
        final app = partialApp.dummySign(pubkey);

        await storage.save({app});

        Release? latestReleaseValue;

        // EXACT zapstore pattern
        final provider = model<App>(
          app,
          and: (a) => {a.latestRelease},
          source: LocalSource(), // Main query is local-only
          andSource: LocalAndRemoteSource(
            stream: false,
          ), // Relationships from remote, non-streaming
        );

        final sub = container.listen(provider, (_, state) {
          if (state is StorageData<App> && state.models.isNotEmpty) {
            latestReleaseValue = state.models.first.latestRelease.value;
          }
        });

        container.read(provider);
        await Future.delayed(const Duration(milliseconds: 50));

        final notifier = container.read(provider.notifier);

        // KEY CHECK: Are relationship queries triggered when source is LocalSource?
        // With the fix, andSource is checked when source is LocalSource
        expect(
          notifier.mergedRelationshipRequests,
          isNotEmpty,
          reason:
              'Relationship queries should fire via andSource even when source is LocalSource',
        );

        // Save release (simulates data arriving from relay)
        await storage.save({release});
        await Future.delayed(const Duration(milliseconds: 100));

        // Did the relationship get loaded?
        expect(
          latestReleaseValue,
          isNotNull,
          reason:
              'Relationship should be discovered even with source: LocalSource',
        );

        sub.close();
      },
    );
  });
}

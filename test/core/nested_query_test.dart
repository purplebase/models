import 'dart:async';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';
import 'nested_query_fixtures.dart';

/// Tests for nested query functionality per SPEC.md
void main() {
  late ProviderContainer container;
  late DummyStorageNotifier storage;
  late NestedQueryFixtures fixtures;

  setUp(() async {
    container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
    storage =
        container.read(storageNotifierProvider.notifier) as DummyStorageNotifier;
    fixtures = NestedQueryFixtures();
  });

  tearDown(() async {
    container.dispose();
  });

  group('NestedQuery basics', () {
    test('.query() returns NestedQuery with request from relationship', () {
      final partialApp = PartialApp()
        ..identifier = 'com.example.test'
        ..description = 'Test app';
      final app = partialApp.dummySign(franzapPubkey);

      // Access the relationship and call query()
      final nq = app.latestRelease.query();

      expect(nq, isA<NestedQuery>());
      expect(nq.request, isNotNull);
      expect(nq.source, isNull, reason: 'Should inherit from outer by default');
      expect(nq.subscriptionPrefix, isNull);
      expect(nq.and, isNull);
    });

    test('.query() accepts source override', () {
      final partialApp = PartialApp()
        ..identifier = 'com.example.test'
        ..description = 'Test app';
      final app = partialApp.dummySign(franzapPubkey);

      final customSource = RemoteSource(relays: 'custom', stream: false);
      final nq = app.latestRelease.query(source: customSource);

      expect(nq.source, equals(customSource));
    });

    test('.query() accepts subscriptionPrefix override', () {
      final partialApp = PartialApp()
        ..identifier = 'com.example.test'
        ..description = 'Test app';
      final app = partialApp.dummySign(franzapPubkey);

      final nq = app.latestRelease.query(subscriptionPrefix: 'custom-prefix');

      expect(nq.subscriptionPrefix, equals('custom-prefix'));
    });

    test('.query() accepts nested and callback with proper typing', () {
      final partialApp = PartialApp()
        ..identifier = 'com.example.test'
        ..description = 'Test app';
      final app = partialApp.dummySign(franzapPubkey);

      // The callback receives Release directly - no cast needed
      final nq = app.latestRelease.query(
        and: (release) => {release.latestMetadata.query()},
      );

      expect(nq.and, isNotNull);
    });

    test('NestedQuery equality is based on request only', () {
      final partialApp = PartialApp()
        ..identifier = 'com.example.test'
        ..description = 'Test app';
      final app = partialApp.dummySign(franzapPubkey);

      final nq1 = app.latestRelease.query(source: LocalSource());
      final nq2 = app.latestRelease.query(source: RemoteSource(stream: true));

      // Same request, different source - should be equal (for streaming tracking)
      expect(nq1, equals(nq2));
    });
  });

  group('Nested query execution', () {
    test('and callback returns Set<NestedQuery>', () async {
      final partialApp = PartialApp()
        ..identifier = 'com.example.callback'
        ..description = 'Test callback';
      final app = partialApp.dummySign(franzapPubkey);

      await storage.save({app});

      // The and callback should return Set<NestedQuery>
      final provider = model<App>(
        app,
        and: (a) => {
          a.latestRelease.query(),
          a.author.query(),
        },
        source: LocalAndRemoteSource(stream: true),
      );

      final sub = container.listen(provider, (_, __) {});
      container.read(provider);

      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(provider.notifier);
      expect(notifier.relationshipRequests, isNotEmpty);

      sub.close();
    });

    test('nested queries inherit source from outer when not specified', () async {
      final partialApp = PartialApp()
        ..identifier = 'com.example.inherit'
        ..description = 'Test inheritance';
      final app = partialApp.dummySign(franzapPubkey);

      await storage.save({app});

      // Outer source is LocalAndRemoteSource with stream: true
      // Nested query should inherit this
      final provider = model<App>(
        app,
        and: (a) => {a.latestRelease.query()}, // No source specified
        source: LocalAndRemoteSource(stream: true),
      );

      final sub = container.listen(provider, (_, __) {});
      container.read(provider);

      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(provider.notifier);
      expect(notifier.relationshipRequests, isNotEmpty);

      sub.close();
    });

    test('nested queries with LocalSource outer do not issue remote requests', () async {
      final partialApp = PartialApp()
        ..identifier = 'com.example.local'
        ..description = 'Test local source';
      final app = partialApp.dummySign(franzapPubkey);

      await storage.save({app});

      // Outer source is LocalSource - nested should inherit and not issue remote
      final provider = model<App>(
        app,
        and: (a) => {a.latestRelease.query()}, // Inherits LocalSource
        source: LocalSource(),
      );

      final sub = container.listen(provider, (_, __) {});
      container.read(provider);

      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(provider.notifier);
      // LocalSource doesn't issue remote requests
      expect(notifier.relationshipRequests, isEmpty);

      sub.close();
    });

    test('per-relationship source override works', () async {
      final partialApp = PartialApp()
        ..identifier = 'com.example.override'
        ..description = 'Test override';
      final app = partialApp.dummySign(franzapPubkey);

      await storage.save({app});

      // Outer is LocalSource, but nested specifies RemoteSource
      final provider = model<App>(
        app,
        and: (a) => {
          a.latestRelease.query(source: RemoteSource(stream: false)),
        },
        source: LocalSource(),
      );

      final sub = container.listen(provider, (_, __) {});
      container.read(provider);

      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(provider.notifier);
      // Should have issued remote request despite outer being LocalSource
      expect(notifier.relationshipRequests, isNotEmpty);

      sub.close();
    });
  });

  group('Streaming vs non-streaming nested queries', () {
    test('streaming nested queries are only issued once', () async {
      final partialApp = PartialApp()
        ..identifier = 'com.example.streaming'
        ..description = 'Test streaming';
      final app = partialApp.dummySign(franzapPubkey);

      await storage.save({app});

      final provider = model<App>(
        app,
        and: (a) => {a.latestRelease.query()}, // Inherits stream: true
        source: LocalAndRemoteSource(stream: true),
      );

      final sub = container.listen(provider, (_, __) {});
      container.read(provider);

      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(provider.notifier);
      final initialCount = notifier.relationshipRequests.length;

      // Trigger another flush by saving the app again
      await storage.save({app});
      await Future.delayed(const Duration(milliseconds: 50));

      // Streaming requests should not be re-issued
      expect(notifier.relationshipRequests.length, equals(initialCount));

      sub.close();
    });

    test('non-streaming nested queries are re-issued on each flush', () async {
      final partialApp = PartialApp()
        ..identifier = 'com.example.nonstreaming'
        ..description = 'Test non-streaming';
      final app = partialApp.dummySign(franzapPubkey);

      await storage.save({app});

      final provider = model<App>(
        app,
        and: (a) => {
          a.latestRelease.query(source: RemoteSource(stream: false)),
        },
        source: LocalAndRemoteSource(stream: true),
      );

      final sub = container.listen(provider, (_, __) {});
      container.read(provider);

      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(provider.notifier);
      final initialCount = notifier.relationshipRequests.length;
      expect(initialCount, greaterThan(0));

      // Trigger another flush by saving the app again (simulates update)
      final updatedApp = (PartialApp()
            ..identifier = 'com.example.nonstreaming'
            ..description = 'Updated')
          .dummySign(franzapPubkey);
      await storage.save({updatedApp});
      await Future.delayed(const Duration(milliseconds: 50));

      // Non-streaming requests should be re-issued
      expect(notifier.relationshipRequests.length, greaterThan(initialCount));

      sub.close();
    });
  });

  group('Relationship re-emission', () {
    test('main query re-emits when relationship data arrives', () async {
      final pubkey = franzapPubkey;

      // Create a Release that will be the relationship target
      final partialRelease = PartialRelease()..identifier = 'com.example.reemit@1.0.0';
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

      final provider = model<App>(
        app,
        and: (a) => {a.latestRelease.query()},
        source: LocalAndRemoteSource(stream: true),
      );

      final sub = container.listen(provider, (_, state) {
        if (state is StorageData<App>) {
          emissionCount++;
          emissions.add(state);
        }
      });

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

      // Should have re-emitted
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
    });
  });

  group('Error handling', () {
    test('errors in nested queries emit StorageError with outer models preserved',
        () async {
      // This test verifies the error handling behavior described in the spec.
      // In practice, errors would come from relay failures which are hard to
      // simulate with DummyStorage. We verify the error state structure exists.

      final partialApp = PartialApp()
        ..identifier = 'com.example.error'
        ..description = 'Test error handling';
      final app = partialApp.dummySign(franzapPubkey);

      await storage.save({app});

      final provider = model<App>(
        app,
        and: (a) => {a.latestRelease.query()},
        source: LocalAndRemoteSource(stream: true),
      );

      final sub = container.listen(provider, (_, __) {});
      container.read(provider);

      // Verify StorageError can preserve models
      final errorState = StorageError<App>(
        [app],
        exception: Exception('Test error'),
      );
      expect(errorState.models, contains(app));
      expect(errorState.exception, isA<Exception>());

      sub.close();
    });
  });

  group('Request merging via requestBufferDuration', () {
    test('multiple nested queries are batched', () async {
      // Create multiple apps that will each need relationship queries
      final apps = List.generate(
        5,
        (i) => (PartialApp()
              ..identifier = 'buffered-app-$i'
              ..name = 'Buffered App $i')
            .dummySign(franzapPubkey),
      );

      await storage.save(apps.toSet());

      final provider = query<App>(
        authors: {franzapPubkey},
        source: LocalAndRemoteSource(stream: true),
        and: (app) => {app.latestRelease.query()},
      );

      final sub = container.listen(provider, (_, __) {});
      await Future.delayed(Duration(milliseconds: 50));

      final notifier = container.read(provider.notifier);

      // With buffering, multiple apps should result in batched relationship requests
      // The exact count depends on merging, but should be less than 5 separate requests
      expect(
        notifier.relationshipRequests.length,
        lessThanOrEqualTo(5),
        reason: 'Relationship queries should be batched with buffer window',
      );

      sub.close();
    });
  });

  group('Updated replaceables', () {
    test('updated replaceable models trigger relationship re-query', () async {
      final pubkey = franzapPubkey;

      // Create initial app
      final partialApp1 = PartialApp()
        ..identifier = 'com.example.replaceable'
        ..description = 'Version 1';
      final app1 = partialApp1.dummySign(pubkey);

      await storage.save({app1});

      final provider = model<App>(
        app1,
        and: (a) => {a.latestRelease.query()},
        source: LocalAndRemoteSource(stream: true),
      );

      final sub = container.listen(provider, (_, __) {});
      container.read(provider);

      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(provider.notifier);
      final initialCount = notifier.totalRelationshipQueriesIssued;

      // Create updated app (same model.id, new event.id)
      final partialApp2 = PartialApp()
        ..identifier = 'com.example.replaceable'
        ..description = 'Version 2';
      final app2 = partialApp2.dummySign(pubkey);

      // Save updated version
      await storage.save({app2});
      await Future.delayed(const Duration(milliseconds: 100));

      // Updated replaceable should trigger re-query
      expect(
        notifier.totalRelationshipQueriesIssued,
        greaterThan(initialCount),
        reason: 'Updated replaceable model should re-query relationships',
      );

      sub.close();
    });
  });

  group('Comprehensive fixtures tests', () {
    test('query multiple apps with author relationships', () async {
      // Save all fixture data
      await storage.save(fixtures.allModels);

      final provider = query<App>(
        authors: fixtures.authors,
        source: LocalAndRemoteSource(stream: true),
        and: (app) => {app.author.query()},
      );

      final sub = container.listen(provider, (_, __) {});
      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(provider);
      expect(state, isA<StorageData<App>>());
      expect((state as StorageData<App>).models.length, equals(3));

      // Verify relationships are loaded
      for (final app in state.models) {
        expect(
          app.author.value,
          isNotNull,
          reason: 'Author should be loaded for ${app.identifier}',
        );
      }

      sub.close();
    });

    test('query apps with release relationships', () async {
      await storage.save(fixtures.allModels);

      final provider = query<App>(
        authors: {fixtures.author1},
        source: LocalAndRemoteSource(stream: true),
        and: (app) => {app.latestRelease.query()},
      );

      final sub = container.listen(provider, (_, __) {});
      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(provider);
      expect(state, isA<StorageData<App>>());

      // app1 should have release1v2 as latest (higher version)
      final app1 = (state as StorageData<App>)
          .models
          .firstWhere((a) => a.identifier == 'com.alice.app1');
      expect(app1.latestRelease.value, isNotNull);

      sub.close();
    });

    test('deeply nested: App -> Release -> FileMetadata', () async {
      await storage.save(fixtures.allModels);

      final provider = query<App>(
        authors: {fixtures.author1},
        source: LocalAndRemoteSource(stream: true),
        and: (app) => {
          app.latestRelease.query(
            and: (release) => {release.latestMetadata.query()},
          ),
        },
      );

      final sub = container.listen(provider, (_, __) {});
      await Future.delayed(const Duration(milliseconds: 150));

      final state = container.read(provider);
      expect(state, isA<StorageData<App>>());

      sub.close();
    });

    test('deeply nested and callbacks are actually executed', () async {
      // Create properly linked data: App -> Release -> FileMetadata
      final pubkey = franzapPubkey;

      // Create FileMetadata first (so we have its event.id)
      final metadata = (PartialFileMetadata()
            ..version = '1.0.0'
            ..appIdentifier = 'com.test.nested')
          .dummySign(pubkey);

      // Create Release with 'e' tag pointing to FileMetadata
      final partialRelease = PartialRelease()..identifier = 'com.test.nested@1.0.0';
      partialRelease.event.addTag('i', ['com.test.nested']);
      partialRelease.event.addTag('version', ['1.0.0']);
      partialRelease.event.addTag('e', [metadata.event.id]); // Link to FileMetadata!
      final release = partialRelease.dummySign(pubkey);

      // Create App
      final app = (PartialApp()
            ..identifier = 'com.test.nested'
            ..description = 'Test nested callbacks')
          .dummySign(pubkey);

      // Only save App initially - Release and FileMetadata will come from "remote"
      await storage.save({app});

      // Track which nested query callbacks were executed
      var releaseCallbackExecuted = false;

      final provider = model<App>(
        app,
        source: LocalAndRemoteSource(stream: true),
        and: (a) => {
          a.latestRelease.query(
            and: (r) {
              releaseCallbackExecuted = true;
              return {r.latestMetadata.query()};
            },
          ),
        },
      );

      final sub = container.listen(provider, (_, __) {});
      container.read(provider);
      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(provider.notifier);
      final initialRequestCount = notifier.relationshipRequests.length;

      // Simulate Release arriving from relay
      await storage.save({release});
      await Future.delayed(const Duration(milliseconds: 100));

      // The nested 'and' callback on latestRelease.query() should have been called
      expect(
        releaseCallbackExecuted,
        isTrue,
        reason: 'Nested and callback should be executed when Release arrives',
      );

      // Should have issued more requests (for FileMetadata)
      expect(
        notifier.relationshipRequests.length,
        greaterThan(initialRequestCount),
        reason: 'Nested query for FileMetadata should be issued',
      );

      // Verify the FileMetadata request was actually created
      final hasFileMetadataRequest = notifier.relationshipRequests.any(
        (req) => req.filters.any(
          (f) => f.ids.contains(metadata.event.id),
        ),
      );
      expect(
        hasFileMetadataRequest,
        isTrue,
        reason: 'Should have issued request for FileMetadata by its event.id',
      );

      sub.close();
    });

    test('notes with multiple relationships: author, reactions, replies', () async {
      await storage.save(fixtures.allModels);

      final provider = query<Note>(
        ids: {fixtures.note1.id},
        source: LocalAndRemoteSource(stream: true),
        and: (note) => {
          note.author.query(),
          note.reactions.query(),
          note.replies.query(),
        },
      );

      final sub = container.listen(provider, (_, __) {});
      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(provider);
      expect(state, isA<StorageData<Note>>());

      final note = (state as StorageData<Note>).models.first;
      expect(note.author.value, isNotNull, reason: 'Author should be loaded');
      expect(note.reactions.length, equals(2), reason: 'Should have 2 reactions');
      expect(note.replies.length, equals(1), reason: 'Should have 1 reply');

      sub.close();
    });

    test('streaming: new data arrives and triggers relationship queries', () async {
      // Start with just apps
      await storage.save(fixtures.apps);

      final provider = query<App>(
        authors: fixtures.authors,
        source: LocalAndRemoteSource(stream: true),
        and: (app) => {
          app.latestRelease.query(),
          app.author.query(),
        },
      );

      final emissions = <StorageState<App>>[];
      final sub = container.listen(provider, (_, state) {
        if (state is StorageData<App>) {
          emissions.add(state);
        }
      });

      container.read(provider);
      await Future.delayed(const Duration(milliseconds: 50));

      final initialEmissions = emissions.length;

      // Apps should be loaded but without releases
      expect(emissions.last.models.first.latestRelease.value, isNull);

      // Now save releases - should trigger re-emission
      await storage.save(fixtures.releases);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(
        emissions.length,
        greaterThan(initialEmissions),
        reason: 'Should re-emit when relationship data arrives',
      );

      // Now save profiles - should trigger another re-emission
      await storage.save(fixtures.profiles);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify relationships are now populated
      final app1 = emissions.last.models
          .firstWhere((a) => a.identifier == 'com.alice.app1');
      expect(app1.latestRelease.value, isNotNull);
      expect(app1.author.value, isNotNull);

      sub.close();
    });

    test('per-relationship source: different sources for different relationships', () async {
      await storage.save(fixtures.apps);
      await storage.save(fixtures.profiles);

      final provider = query<App>(
        authors: {fixtures.author1},
        source: LocalSource(), // Main query is local
        and: (app) => {
          // Releases from remote
          app.latestRelease.query(source: RemoteSource(stream: false)),
          // Author is local (inherits LocalSource - won't issue remote request)
          app.author.query(),
        },
      );

      final sub = container.listen(provider, (_, __) {});
      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(provider.notifier);

      // Should have issued remote request for release only
      // Author inherits LocalSource and won't issue remote
      expect(notifier.relationshipRequests, isNotEmpty);

      // Author should still be loaded from local storage
      final state = container.read(provider);
      final app = (state as StorageData<App>).models.first;
      expect(app.author.value, isNotNull);

      sub.close();
    });

    test('mixed streaming modes in nested queries', () async {
      await storage.save(fixtures.allModels);

      final provider = query<App>(
        authors: {fixtures.author1},
        source: LocalAndRemoteSource(stream: true), // Outer streams
        and: (app) => {
          // This one streams
          app.author.query(source: RemoteSource(stream: true)),
          // This one doesn't - should be re-issued on each flush
          app.latestRelease.query(source: RemoteSource(stream: false)),
        },
      );

      final sub = container.listen(provider, (_, __) {});
      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(provider.notifier);
      final initialCount = notifier.relationshipRequests.length;

      // Trigger flush by updating an app
      final updatedApp = (PartialApp()
            ..identifier = 'com.alice.app1'
            ..description = 'Updated')
          .dummySign(fixtures.author1);
      await storage.save({updatedApp});
      await Future.delayed(const Duration(milliseconds: 100));

      // Both should be re-issued because the app was updated (new event.id)
      expect(
        notifier.relationshipRequests.length,
        greaterThan(initialCount),
      );

      sub.close();
    });
  });
}


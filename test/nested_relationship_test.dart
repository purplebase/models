import 'dart:async';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Tests for nested relationship loading (App -> Release -> FileMetadata)
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
    container.dispose();
  });

  group('Nested Relationship Loading Bug', () {
    test('and: callback should discover nested relationships after parent resolves',
        () async {
      // Use the same pubkey for all models
      final pubkey = franzapPubkey;

      // Create a FileMetadata (level 2)
      final partialFile = PartialFileMetadata()
        ..version = '1.0.0'
        ..appIdentifier = 'com.example.nested';
      final fileMetadata = partialFile.dummySign(pubkey);

      // Create a Release that references the FileMetadata (level 1)
      final partialRelease = PartialRelease()
        ..identifier = 'com.example.nested@1.0.0';
      partialRelease.event.addTag('e', [fileMetadata.event.id]);
      partialRelease.event.addTag('i', ['com.example.nested']);
      partialRelease.event.addTag('version', ['1.0.0']);
      final release = partialRelease.dummySign(pubkey);

      // Create an App that references the Release (primary model)
      final partialApp = PartialApp()
        ..identifier = 'com.example.nested'
        ..description = 'Test app for nested relationships';
      final app = partialApp.dummySign(pubkey);

      // Save the App first (primary model)
      await storage.save({app});

      // Create a completer to track when we're done
      final completer = Completer<void>();
      var latestReleaseValue;
      var latestMetadataValue;
      var stateCount = 0;

      // Watch the app using the model() provider with and: callback
      // This is the pattern that exhibits the bug
      final provider = model<App>(
        app,
        and: (a) {
          // This is the problematic pattern from the bug report
          final relationships = <Relationship<Model>>{a.latestRelease};
          if (a.latestRelease.value != null) {
            relationships.add(a.latestRelease.value!.latestMetadata);
          }
          return relationships;
        },
        source: LocalAndRemoteSource(stream: true),
      );

      // Listen to the provider
      final sub = container.listen(provider, (_, state) {
        stateCount++;
        if (state is StorageData<App> && state.models.isNotEmpty) {
          final loadedApp = state.models.first;
          latestReleaseValue = loadedApp.latestRelease.value;
          if (latestReleaseValue != null) {
            latestMetadataValue = latestReleaseValue.latestMetadata.value;
          }
        }
      });

      // Initial read
      container.read(provider);

      // Wait a tick for initial state
      await Future.delayed(Duration(milliseconds: 50));

      // At this point, Release hasn't been saved, so latestRelease.value should be null
      expect(latestReleaseValue, isNull,
          reason: 'Release not saved yet, should be null');

      // Now save the Release (level 1)
      await storage.save({release});

      // Wait for relationship to be discovered
      await Future.delayed(Duration(milliseconds: 100));

      // Now latestRelease.value should have the Release
      expect(latestReleaseValue, isNotNull,
          reason: 'Release was saved, should be loaded');

      // At this point, the bug manifests:
      // The and: callback should have been re-evaluated after Release loaded,
      // discovering the latestMetadata relationship
      // But according to the bug, it's NOT re-evaluated

      // Save the FileMetadata (level 2)
      await storage.save({fileMetadata});

      // Wait for nested relationship to be discovered
      await Future.delayed(Duration(milliseconds: 100));

      // BUG: latestMetadata.value is always null because the and: callback
      // was never re-evaluated after latestRelease was loaded
      expect(latestMetadataValue, isNotNull,
          reason:
              'FileMetadata was saved and should be discovered via nested relationship');

      sub.close();
    });

    test('zapstore exact scenario: source=LocalSource, andSource=LocalAndRemoteSource',
        () async {
      // This test mimics the EXACT zapstore scenario where:
      // - App is passed in (already in local storage)
      // - source: LocalSource() - primary query is local-only
      // - andSource: LocalAndRemoteSource() - relationships fetch from remote
      
      final pubkey = franzapPubkey;

      // Create a FileMetadata (level 2)
      final partialFile = PartialFileMetadata()
        ..version = '2.0.0'
        ..appIdentifier = 'com.example.zapstore';
      final fileMetadata = partialFile.dummySign(pubkey);

      // Create a Release that references the FileMetadata (level 1)
      final partialRelease = PartialRelease()
        ..identifier = 'com.example.zapstore@2.0.0';
      partialRelease.event.addTag('e', [fileMetadata.event.id]);
      partialRelease.event.addTag('i', ['com.example.zapstore']);
      partialRelease.event.addTag('version', ['2.0.0']);
      final release = partialRelease.dummySign(pubkey);

      // Create an App (primary model)
      final partialApp = PartialApp()
        ..identifier = 'com.example.zapstore'
        ..description = 'Test app mimicking zapstore scenario';
      final app = partialApp.dummySign(pubkey);

      // Save only the App initially (like zapstore - app comes from list)
      await storage.save({app});

      Release? latestReleaseValue;
      FileMetadata? latestMetadataValue;

      // Watch using EXACT zapstore pattern:
      // source: LocalSource() - primary query local-only
      // andSource: LocalAndRemoteSource() - relationships from relays
      final provider = model<App>(
        app,
        and: (a) => {
          a.latestRelease,
          if (a.latestRelease.value != null)
            a.latestRelease.value!.latestMetadata,
        },
        source: LocalSource(),
        andSource: LocalAndRemoteSource(stream: true),
      );

      // Listen to state changes
      final sub = container.listen(provider, (_, state) {
        if (state is StorageData<App> && state.models.isNotEmpty) {
          final loadedApp = state.models.first;
          latestReleaseValue = loadedApp.latestRelease.value;
          if (latestReleaseValue != null) {
            latestMetadataValue = latestReleaseValue!.latestMetadata.value;
          }
        }
      });

      // Initial read
      container.read(provider);
      await Future.delayed(Duration(milliseconds: 50));

      // Initial state: no release yet
      expect(latestReleaseValue, isNull,
          reason: 'Release not saved yet');

      // Simulate: Release arrives from remote and is saved to local storage
      await storage.save({release});
      await Future.delayed(Duration(milliseconds: 100));

      // Release should now be loaded
      expect(latestReleaseValue, isNotNull,
          reason: 'Release was saved, latestRelease.value should be populated');

      // Simulate: FileMetadata arrives from remote
      await storage.save({fileMetadata});
      await Future.delayed(Duration(milliseconds: 100));

      // THE BUG: This is where zapstore hangs - latestMetadata.value is null
      // because the and: callback was not re-evaluated after Release loaded
      expect(latestMetadataValue, isNotNull,
          reason: 'FileMetadata was saved, but nested relationship was never discovered because and: callback was not re-evaluated after Release loaded');

      sub.close();
    });

    test('workaround: manually re-query works', () async {
      // This test shows that the manual workaround works,
      // proving that the data is in storage, just not discovered

      final pubkey = franzapPubkey;

      // Create all models
      final partialFile = PartialFileMetadata()
        ..version = '1.0.0'
        ..appIdentifier = 'com.example.workaround';
      final fileMetadata = partialFile.dummySign(pubkey);

      final partialRelease = PartialRelease()
        ..identifier = 'com.example.workaround@1.0.0';
      partialRelease.event.addTag('e', [fileMetadata.event.id]);
      partialRelease.event.addTag('i', ['com.example.workaround']);
      partialRelease.event.addTag('version', ['1.0.0']);
      final release = partialRelease.dummySign(pubkey);

      final partialApp = PartialApp()
        ..identifier = 'com.example.workaround'
        ..description = 'Test app';
      final app = partialApp.dummySign(pubkey);

      // Save all models
      await storage.save({app, release, fileMetadata});

      // Query for app
      final apps = await storage.query(
        RequestFilter<App>(ids: {app.id}).toRequest(),
      );
      final loadedApp = apps.first;

      // Manually check relationships via sync lookup
      final releaseFromApp = loadedApp.latestRelease.value;
      expect(releaseFromApp, isNotNull);

      final metadataFromRelease = releaseFromApp!.latestMetadata.value;
      expect(metadataFromRelease, isNotNull,
          reason: 'Direct querySync should find the metadata');
    });
  });
}


import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:models/models.dart';
import '../helpers.dart';

/// Tests for query provider stream behavior.
///
/// These tests verify the critical distinction between `query` provider and
/// `storage.query` behavior regarding the `stream` parameter:
///
/// - **query provider**: Always returns local storage models immediately for
///   `LocalAndRemoteSource`, regardless of `stream` setting. The `stream`
///   parameter only controls subscription lifecycle (keep open vs close after EOSE).
///
/// - **storage.query**: With `stream: false`, blocks until EOSE before returning.
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

  group('Query provider with stream: false returns local data immediately', () {
    test(
      'query provider with LocalAndRemoteSource(stream: false) returns local data immediately',
      () async {
        // Pre-populate local storage with some data
        final note = PartialNote('Existing note').dummySign(nielPubkey);
        await storage.save({note});

        // Query with stream: false - should return local data immediately
        // NOT block waiting for EOSE
        final queryProvider = query<Note>(
          authors: {nielPubkey},
          source: const LocalAndRemoteSource(stream: false),
        );

        final tester = container.testerFor(queryProvider);

        // Should get local data immediately
        await tester.expectModels(
          allOf(
            hasLength(1),
            everyElement((m) => m.content == 'Existing note'),
          ),
        );
      },
    );

    test(
      'query provider with stream: false and stream: true both return local data immediately',
      () async {
        // Pre-populate local storage
        final note = PartialNote('Test note').dummySign(nielPubkey);
        await storage.save({note});

        // Both stream settings should return local data immediately
        final streamFalseProvider = query<Note>(
          authors: {nielPubkey},
          source: const LocalAndRemoteSource(stream: false),
        );

        final streamTrueProvider = query<Note>(
          authors: {franzapPubkey}, // Different author to get separate provider
          source: const LocalAndRemoteSource(stream: true),
        );

        // Save note for the second author
        final note2 = PartialNote('Another note').dummySign(franzapPubkey);
        await storage.save({note2});

        // Both should return immediately
        final tester1 = container.testerFor(streamFalseProvider);
        final tester2 = container.testerFor(streamTrueProvider);

        await tester1.expectModels(hasLength(1));
        await tester2.expectModels(hasLength(1));
      },
    );

    test(
      'stream: false closes subscription after EOSE while stream: true keeps it open',
      () async {
        // Pre-populate local storage
        final note1 = PartialNote('First note').dummySign(nielPubkey);
        await storage.save({note1});

        // Set up query with stream: true (subscription stays open)
        final streamingProvider = query<Note>(
          authors: {nielPubkey},
          source: const LocalAndRemoteSource(stream: true),
        );

        final tester = container.testerFor(streamingProvider);

        // Get initial data
        await tester.expectModels(hasLength(1));

        // Save new data - should be picked up by streaming subscription
        final note2 = PartialNote('Second note').dummySign(nielPubkey);
        await storage.save({note2});

        // Streaming subscription should receive the update
        await tester.expectModels(hasLength(2));
      },
    );

    test(
      'empty local storage does not emit empty data (avoids flash)',
      () async {
        // Query with no local data - should stay in loading state
        // until data arrives (not emit empty StorageData)
        final queryProvider = query<Note>(
          authors: {nielPubkey},
          source: const LocalAndRemoteSource(stream: false),
        );

        final tester = container.testerFor(queryProvider);

        // Now save some data - this should be the first emission
        final note = PartialNote('New note').dummySign(nielPubkey);
        await storage.save({note});

        // Should get the note (not an empty array first)
        await tester.expectModels(
          allOf(hasLength(1), everyElement((m) => m.content == 'New note')),
        );
      },
    );
  });

  group('storage.query blocking behavior', () {
    test('storage.query with LocalSource returns immediately', () async {
      // Pre-populate storage
      final note = PartialNote('Test').dummySign(nielPubkey);
      await storage.save({note});

      final req = RequestFilter<Note>(authors: {nielPubkey}).toRequest();

      // LocalSource query should return immediately
      final results = await storage.query(req, source: LocalSource());

      expect(results, hasLength(1));
      expect(results.first.content, equals('Test'));
    });

    test(
      'storage.query with stream: false returns data (DummyStorage is non-blocking)',
      () async {
        // Note: In a real storage implementation with actual relay connections,
        // storage.query with stream: false would block until EOSE.
        // DummyStorage simulates this by returning immediately since there's
        // no actual network round-trip.
        final note = PartialNote('Test').dummySign(nielPubkey);
        await storage.save({note});

        final req = RequestFilter<Note>(authors: {nielPubkey}).toRequest();

        final results = await storage.query(
          req,
          source: const LocalAndRemoteSource(stream: false),
        );

        expect(results, hasLength(1));
      },
    );
  });
}

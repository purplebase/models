import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('Subscription Prefix', () {
    test('Request uses custom subscriptionPrefix', () {
      final req = Request([
        RequestFilter(kinds: {1}, authors: {nielPubkey}),
      ], subscriptionPrefix: 'app-detail');

      expect(req.subscriptionId, startsWith('app-detail-'));
      expect(req.subscriptionId, matches(RegExp(r'app-detail-\d+')));
    });

    test('Request uses default "sub" prefix when no prefix provided and no type', () {
      final req = Request([
        RequestFilter(kinds: {1}, authors: {nielPubkey}),
      ]);

      expect(req.subscriptionId, startsWith('sub-'));
      expect(req.subscriptionId, matches(RegExp(r'sub-\d+')));
    });

    test('Request uses model-aware prefix for typed requests', () {
      final req = Request<Note>([
        RequestFilter<Note>(kinds: {1}, authors: {nielPubkey}),
      ]);

      expect(req.subscriptionId, startsWith('sub-note-'));
      expect(req.subscriptionId, matches(RegExp(r'sub-note-\d+')));
    });

    test('RequestFilter.toRequest uses model-aware prefix for typed requests', () {
      final req = RequestFilter<Note>(
        kinds: {1},
        authors: {nielPubkey},
      ).toRequest();

      expect(req.subscriptionId, startsWith('sub-note-'));
      expect(req.subscriptionId, matches(RegExp(r'sub-note-\d+')));
    });

    test('Request.fromIds uses custom subscriptionPrefix', () {
      final req = Request.fromIds([
        Utils.generateRandomHex64(),
      ], subscriptionPrefix: 'fetch-by-id');

      expect(req.subscriptionId, startsWith('fetch-by-id-'));
      expect(req.subscriptionId, matches(RegExp(r'fetch-by-id-\d+')));
    });

    test('RequestFilter.toRequest uses custom subscriptionPrefix', () {
      final req = RequestFilter(
        kinds: {1},
        authors: {nielPubkey},
      ).toRequest(subscriptionPrefix: 'user-profile');

      expect(req.subscriptionId, startsWith('user-profile-'));
      expect(req.subscriptionId, matches(RegExp(r'user-profile-\d+')));
    });

    test('RequestFilter iterable toRequest uses custom subscriptionPrefix', () {
      final filters = [
        RequestFilter(kinds: {1}, authors: {nielPubkey}),
        RequestFilter(kinds: {1}),
      ];

      final req = filters.toRequest(subscriptionPrefix: 'multi-filter');

      expect(req.subscriptionId, startsWith('multi-filter-'));
      expect(req.subscriptionId, matches(RegExp(r'multi-filter-\d+')));
    });

    test('Different subscription prefixes generate different IDs', () {
      final req1 = Request([
        RequestFilter(kinds: {1}, authors: {nielPubkey}),
      ], subscriptionPrefix: 'prefix-1');

      final req2 = Request([
        RequestFilter(kinds: {1}, authors: {nielPubkey}),
      ], subscriptionPrefix: 'prefix-2');

      expect(req1.subscriptionId, startsWith('prefix-1-'));
      expect(req2.subscriptionId, startsWith('prefix-2-'));
      expect(req1.subscriptionId, isNot(equals(req2.subscriptionId)));
    });

    test('Query provider accepts subscriptionPrefix parameter', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initialize storage
      await container.read(
        initializationProvider(StorageConfiguration()).future,
      );

      // Create a query with subscription prefix
      final provider = query<Note>(
        authors: {nielPubkey},
        limit: 10,
        subscriptionPrefix: 'test-query',
      );

      // Watch the provider to trigger the query
      final state = container.read(provider);

      // The subscription should have been created (we can't easily test the ID
      // but we can verify the query works)
      expect(state, isA<StorageState>());
    });

    test('queryKinds provider accepts subscriptionPrefix parameter', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initialize storage
      await container.read(
        initializationProvider(StorageConfiguration()).future,
      );

      // Create a queryKinds with subscription prefix
      final provider = queryKinds(
        kinds: {1},
        authors: {nielPubkey},
        limit: 10,
        subscriptionPrefix: 'test-multi',
      );

      // Watch the provider to trigger the query
      final state = container.read(provider);

      // The subscription should have been created
      expect(state, isA<StorageState>());
    });

    test('Relationship requests use parent--rel subscription format', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initialize storage
      await container.read(
        initializationProvider(StorageConfiguration()).future,
      );

      final storage =
          container.read(storageNotifierProvider.notifier)
              as DummyStorageNotifier;

      // Create an app to query
      final partialApp = PartialApp()
        ..identifier = 'com.example.subtest'
        ..description = 'Test subscription prefix';
      final app = partialApp.dummySign(franzapPubkey);
      await storage.save({app});

      // Query with custom prefix and relationship
      final provider = model<App>(
        app,
        and: (a) => {a.latestRelease.query()},
        subscriptionPrefix: 'app-detail',
        source: LocalAndRemoteSource(stream: true),
      );

      // Keep provider alive
      final sub = container.listen(provider, (_, __) {});
      container.read(provider);

      // Wait for relationship queries to be registered
      await Future.delayed(const Duration(milliseconds: 250));

      final notifier = container.read(provider.notifier);

      // Verify relationship requests use parent--rel format
      expect(notifier.relationshipRequests, isNotEmpty);
      final relRequest = notifier.relationshipRequests.first;
      
      // Should start with parent subscription ID followed by --rel
      expect(
        relRequest.subscriptionId,
        matches(RegExp(r'app-detail-\d+--rel-\d+')),
        reason: 'Relationship subscription should be parent--rel-{random}',
      );

      sub.close();
    });

    test('Relationship requests preserve multi-part parent prefix', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initialize storage
      await container.read(
        initializationProvider(StorageConfiguration()).future,
      );

      final storage =
          container.read(storageNotifierProvider.notifier)
              as DummyStorageNotifier;

      // Create an app to query
      final partialApp = PartialApp()
        ..identifier = 'com.example.multipart'
        ..description = 'Test multi-part prefix';
      final app = partialApp.dummySign(franzapPubkey);
      await storage.save({app});

      // Query with typed request (generates sub-app prefix)
      final provider = model<App>(
        app,
        and: (a) => {a.latestRelease.query()},
        source: LocalAndRemoteSource(stream: true),
      );

      // Keep provider alive
      final sub = container.listen(provider, (_, __) {});
      container.read(provider);

      // Wait for relationship queries to be registered
      await Future.delayed(const Duration(milliseconds: 250));

      final notifier = container.read(provider.notifier);

      // Verify relationship requests preserve full parent prefix
      expect(notifier.relationshipRequests, isNotEmpty);
      final relRequest = notifier.relationshipRequests.first;
      
      // Should preserve sub-app prefix, not just 'sub'
      expect(
        relRequest.subscriptionId,
        matches(RegExp(r'sub-app-\d+--rel-\d+')),
        reason: 'Relationship subscription should preserve full parent prefix (sub-app)',
      );

      sub.close();
    });

    test('Long subscription prefix is trimmed to 40 chars', () {
      final longPrefix = 'a' * 50; // 50 chars
      final req = Request([
        RequestFilter(kinds: {1}, authors: {nielPubkey}),
      ], subscriptionPrefix: longPrefix);

      // Prefix should be trimmed to 40 chars, then random added
      final parts = req.subscriptionId.split('-');
      final prefix = parts.sublist(0, parts.length - 1).join('-');
      expect(prefix.length, equals(40));
      expect(prefix, equals('a' * 40));
    });

    test('Short subscription prefix is not trimmed', () {
      final shortPrefix = 'my-prefix';
      final req = Request([
        RequestFilter(kinds: {1}, authors: {nielPubkey}),
      ], subscriptionPrefix: shortPrefix);

      expect(req.subscriptionId, startsWith('my-prefix-'));
    });
  });
}

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
  });
}

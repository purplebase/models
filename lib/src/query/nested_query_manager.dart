import 'dart:async';

import '../core/model.dart';
import '../core/types.dart';
import '../filter/request.dart';
import '../filter/request_filter.dart';
import '../relationship/nested_query.dart';
import '../source/source.dart';
import '../source/remote_source.dart';
import '../storage/storage_notifier.dart';
import 'remote_query_buffer.dart';

/// Extracted, testable nested query logic.
///
/// Handles `and` callback processing, streaming subscriptions for
/// relationship queries, and nested-of-nested query resolution.
class NestedQueryManager {
  final StorageNotifier _storage;
  final String _parentSubscriptionId;
  final Source _outerSource;
  final RemoteQueryBuffer _queryBuffer;

  /// model.id → event.id (bounded: one per model).
  final Map<String, String> _processedEventIds = {};

  /// Active streaming subs: unprefixed → prefixed.
  final Map<Request, Request> _streamingToPrefixed = {};

  /// Active relationship subscription IDs (Set, O(1) lookup).
  final Set<String> _activeRelationshipSubIds = {};

  /// All relationship requests issued (for cancellation and testing).
  final List<Request> _relationshipRequests = [];

  /// Counter for total relationship queries issued.
  int _totalRelationshipQueriesIssued = 0;

  /// Pending and-callbacks keyed by prefixed subscription ID.
  final Map<String, (NestedQuery, Source)> _pendingCallbacks = {};

  /// Exposed for testing.
  List<Request> get relationshipRequests => _relationshipRequests;
  int get totalRelationshipQueriesIssued => _totalRelationshipQueriesIssued;
  Set<String> get activeRelationshipSubIds => _activeRelationshipSubIds;

  NestedQueryManager({
    required StorageNotifier storage,
    required String parentSubscriptionId,
    required Source outerSource,
    required RemoteQueryBuffer queryBuffer,
  })  : _storage = storage,
        _parentSubscriptionId = parentSubscriptionId,
        _outerSource = outerSource,
        _queryBuffer = queryBuffer;

  /// Process new/updated models through `and` callbacks.
  void processModels(
    Iterable<Model<dynamic>> models,
    List<AndFunction> andFns,
  ) {
    if (andFns.isEmpty) return;

    final nestedQueries = <NestedQuery>[];

    for (final m in models) {
      final previousEventId = _processedEventIds[m.id];
      final isNewOrUpdated =
          previousEventId == null || previousEventId != m.event.id;

      if (!isNewOrUpdated) continue;

      _processedEventIds[m.id] = m.event.id;

      for (final andFn in andFns) {
        if (andFn != null) {
          nestedQueries.addAll(andFn(m));
        }
      }
    }

    final seen = <Request>{};
    for (final nq in nestedQueries) {
      if (nq.request == null) continue;
      if (seen.contains(nq.request)) continue;
      seen.add(nq.request!);
      _executeNestedQuery(nq);
    }
  }

  /// Check if a storage update is from one of our relationship subscriptions.
  bool isRelationshipUpdate(Request? req) {
    if (req == null) return false;
    final subPrefix = req.subscriptionPrefix;
    return _activeRelationshipSubIds.any(
      (id) => subPrefix.startsWith(_parentSubscriptionId),
    ) || _relationshipRequests.any(
      (r) => subPrefix.startsWith(r.subscriptionPrefix),
    );
  }

  void _executeNestedQuery(NestedQuery nq, {Source? parentResolvedSource}) {
    final request = nq.request;
    if (request == null || request.filters.isEmpty) return;

    final nestedSource = nq.source ?? parentResolvedSource ?? _outerSource;

    if (nestedSource is LocalSource) {
      final prefix =
          nq.subscriptionPrefix ?? '$_parentSubscriptionId--rel';
      final prefixedRequest = request.filters.toRequest(
        subscriptionPrefix: prefix,
      );
      if (!_relationshipRequests.any(
        (r) => r.subscriptionId == prefixedRequest.subscriptionId,
      )) {
        _relationshipRequests.add(prefixedRequest);
        _activeRelationshipSubIds.add(prefixedRequest.subscriptionId);
      }
      return;
    }

    if (nestedSource is! RemoteSource) return;

    final isStreaming = nestedSource.stream;

    final existingPrefixed = _streamingToPrefixed[request];
    if (existingPrefixed != null && isStreaming) {
      _storage.cancel(existingPrefixed);
      _relationshipRequests.remove(existingPrefixed);
      _activeRelationshipSubIds.remove(existingPrefixed.subscriptionId);
      _streamingToPrefixed.remove(request);
      _pendingCallbacks.remove(existingPrefixed.subscriptionId);
    }

    final prefix =
        nq.subscriptionPrefix ?? '$_parentSubscriptionId--rel';
    final prefixedRequest = request.filters.toRequest(
      subscriptionPrefix: prefix,
    );

    _relationshipRequests.add(prefixedRequest);
    _activeRelationshipSubIds.add(prefixedRequest.subscriptionId);
    _totalRelationshipQueriesIssued++;

    if (isStreaming) {
      _streamingToPrefixed[request] = prefixedRequest;
    }

    if (nq.and != null) {
      _pendingCallbacks[prefixedRequest.subscriptionId] = (
        nq,
        nestedSource,
      );
    }

    _queryBuffer
        .bufferQuery(prefixedRequest, nestedSource, prefix)
        .then((_) {
          if (!isStreaming) {
            _pendingCallbacks.remove(prefixedRequest.subscriptionId);
          }

          if (nq.and != null) {
            _processNestedAndCallbacks(nq, prefixedRequest, nestedSource);
          }
        })
        .catchError((e, stack) {
          _pendingCallbacks.remove(prefixedRequest.subscriptionId);
          if (isStreaming) {
            _streamingToPrefixed.remove(request);
          }
        });
  }

  Future<void> _processNestedAndCallbacks(
    NestedQuery nq,
    Request prefixedRequest,
    Source parentResolvedSource,
  ) async {
    if (nq.and == null || nq.request == null) return;

    final models = await _storage.query(nq.request!, source: const LocalSource());

    for (final model in models) {
      final nestedQueries = nq.and!(model);
      for (final nestedNq in nestedQueries) {
        _executeNestedQuery(
          nestedNq,
          parentResolvedSource: parentResolvedSource,
        );
      }
    }
  }

  /// Re-process pending `and` callbacks for streaming relationships.
  ///
  /// Called when a general storage update arrives (e.g., save) that may
  /// provide data that was missing when the callback was first processed.
  void reprocessPendingCallbacks() {
    if (_pendingCallbacks.isEmpty) return;
    for (final entry in Map.of(_pendingCallbacks).entries) {
      final (nq, source) = entry.value;
      _processNestedAndCallbacks(nq, nq.request!.filters.toRequest(
        subscriptionPrefix: entry.key,
      ), source);
    }
  }

  /// Whether there are any pending `and` callbacks waiting for data.
  bool get hasPendingCallbacks => _pendingCallbacks.isNotEmpty;

  /// Dispose all managed subscriptions.
  Future<void> dispose() async {
    await Future.wait(
      _relationshipRequests.map((r) => _storage.cancel(r)),
    );
    _processedEventIds.clear();
    _streamingToPrefixed.clear();
    _pendingCallbacks.clear();
    _activeRelationshipSubIds.clear();
  }
}

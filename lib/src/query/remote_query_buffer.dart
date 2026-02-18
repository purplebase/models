import 'dart:async';

import '../core/model.dart';
import '../filter/request.dart';
import '../filter/request_filter.dart';
import '../source/remote_source.dart';
import '../source/local_and_remote_source.dart';
import '../storage/storage_notifier.dart';

/// Global buffer for batching LocalAndRemoteSource queries.
///
/// When multiple queries arrive within [StorageConfiguration.requestBufferDuration],
/// they are collected, merged into fewer relay requests, and sent together.
///
/// Only non-streaming LocalAndRemoteSource queries are buffered/merged.
/// RemoteSource and streaming queries bypass the buffer.
class RemoteQueryBuffer {
  final StorageNotifier storage;
  Timer? _timer;

  /// Pending queries grouped by source key (relay target).
  final Map<String, List<_PendingQuery>> _pending = {};

  RemoteQueryBuffer(this.storage);

  /// Buffer a query for batched execution.
  ///
  /// Only non-streaming LocalAndRemoteSource queries are buffered.
  /// All other queries go directly to storage.
  Future<List<Model<dynamic>>> bufferQuery(
    Request request,
    RemoteSource source,
    String? subscriptionPrefix,
  ) {
    final shouldBuffer = source is LocalAndRemoteSource && !source.stream;

    if (!shouldBuffer) {
      return storage.query(
        request,
        source: source,
        subscriptionPrefix: subscriptionPrefix,
      );
    }

    final completer = Completer<List<Model<dynamic>>>();
    final key = _sourceKey(source);

    _pending
        .putIfAbsent(key, () => [])
        .add(
          _PendingQuery(
            request: request,
            source: source,
            subscriptionPrefix: subscriptionPrefix,
            completer: completer,
          ),
        );

    _timer?.cancel();

    final bufferDuration = storage.config.requestBufferDuration;
    if (bufferDuration == Duration.zero) {
      _flush();
    } else {
      _timer = Timer(bufferDuration, _flush);
    }

    return completer.future;
  }

  String _sourceKey(RemoteSource source) {
    String relays;
    if (source.relays == null) {
      relays = 'outbox';
    } else if (source.relays is Iterable) {
      final list = (source.relays as Iterable).map((e) => e.toString()).toList()
        ..sort();
      relays = list.join(',');
    } else {
      relays = source.relays.toString();
    }
    return 'local_and_remote:$relays';
  }

  void _flush() {
    if (_pending.isEmpty) return;

    final pendingSnapshot = Map<String, List<_PendingQuery>>.from(_pending);
    _pending.clear();

    for (final entry in pendingSnapshot.entries) {
      final queries = entry.value;
      if (queries.isEmpty) continue;

      final allFilters = queries.expand((q) => q.request.filters).toList();
      final mergedFilters = RequestFilter.mergeMultiple(allFilters);

      final source = queries.first.source;
      final basePrefix = queries.first.subscriptionPrefix;

      final prefix = queries.length > 1
          ? '${basePrefix ?? 'sub'}-merged'
          : basePrefix;

      final mergedRequest = mergedFilters.toRequest(subscriptionPrefix: prefix);

      storage
          .query(mergedRequest, source: source, subscriptionPrefix: prefix)
          .then((_) {
            for (final q in queries) {
              if (!q.completer.isCompleted) {
                q.completer.complete(const []);
              }
            }
          })
          .catchError((e, stack) {
            for (final q in queries) {
              if (!q.completer.isCompleted) {
                q.completer.completeError(e, stack);
              }
            }
          });
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}

class _PendingQuery {
  final Request request;
  final RemoteSource source;
  final String? subscriptionPrefix;
  final Completer<List<Model<dynamic>>> completer;

  _PendingQuery({
    required this.request,
    required this.source,
    required this.subscriptionPrefix,
    required this.completer,
  });
}

/// Query buffer instances, one per storage notifier.
final Expando<RemoteQueryBuffer> queryBuffers = Expando();

RemoteQueryBuffer getQueryBuffer(StorageNotifier storage) {
  return queryBuffers[storage] ??= RemoteQueryBuffer(storage);
}

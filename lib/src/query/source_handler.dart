import 'dart:async';

import '../core/model.dart';
import '../filter/request.dart';
import '../source/source.dart';
import '../source/remote_source.dart';
import '../source/local_and_remote_source.dart';
import '../storage/storage_notifier.dart';
import '../storage/storage_state.dart';
import 'remote_query_buffer.dart';

/// Strategy pattern: each source type gets its own handler.
///
/// The handler is responsible for:
/// - Initial data loading
/// - Handling storage updates (InternalStorageData)
/// - Refreshing data from local storage
sealed class SourceHandler<E extends Model<dynamic>> {
  final StorageNotifier storage;
  final Request<E> req;
  final String? subscriptionPrefix;

  SourceHandler(this.storage, this.req, this.subscriptionPrefix);

  factory SourceHandler.create({
    required Source source,
    required StorageNotifier storage,
    required Request<E> req,
    required String? subscriptionPrefix,
    required RemoteQueryBuffer queryBuffer,
  }) {
    if (source is LocalAndRemoteSource) {
      return LocalAndRemoteSourceHandler(
          storage, req, subscriptionPrefix, source, queryBuffer);
    } else if (source is RemoteSource) {
      return RemoteSourceHandler(
          storage, req, subscriptionPrefix, source, queryBuffer);
    } else {
      return LocalSourceHandler(storage, req, subscriptionPrefix);
    }
  }

  /// Initialize the handler and return initial models.
  Future<List<E>> initialize();

  /// Handle a storage update. Returns new model list if update is relevant, null otherwise.
  Future<List<E>?> handleStorageUpdate(InternalStorageData update);

  /// Refresh from local storage.
  List<E> refreshFromLocal() => storage.querySync(req);
}

/// Local-only source handler.
///
/// Emits immediately from local storage. Refreshes on relevant storage updates.
final class LocalSourceHandler<E extends Model<dynamic>>
    extends SourceHandler<E> {
  LocalSourceHandler(super.storage, super.req, super.subscriptionPrefix);

  @override
  Future<List<E>> initialize() async {
    return storage.querySync(req);
  }

  @override
  Future<List<E>?> handleStorageUpdate(InternalStorageData update) async {
    if (!_isRelevantUpdate(update)) return null;
    return refreshFromLocal();
  }

  bool _isRelevantUpdate(InternalStorageData update) {
    if (update.updatedIds.isEmpty) return true;

    final trackedKinds = req.filters.expand((f) => f.kinds).toSet();
    final trackedAuthors = req.filters.expand((f) => f.authors).toSet();

    for (final filter in req.filters) {
      if (filter.ids.isNotEmpty &&
          filter.ids.intersection(update.updatedIds).isNotEmpty) {
        return true;
      }
    }

    if (trackedKinds.isEmpty && trackedAuthors.isEmpty) return true;

    return true;
  }
}

/// Remote-only source handler.
///
/// Fires remote query, tracks arrival order, emits only models that arrived
/// via our subscription.
final class RemoteSourceHandler<E extends Model<dynamic>>
    extends SourceHandler<E> {
  final RemoteSource source;
  final RemoteQueryBuffer _queryBuffer;

  /// IDs that arrived via our subscription, in arrival order.
  final List<String> _arrivedIds = [];

  RemoteSourceHandler(
      super.storage, super.req, super.subscriptionPrefix, this.source, this._queryBuffer);

  @override
  Future<List<E>> initialize() async {
    if (!source.stream) {
      final models = await _queryBuffer.bufferQuery(req, source, subscriptionPrefix);
      return models.cast<E>();
    }
    await _queryBuffer.bufferQuery(req, source, subscriptionPrefix);
    return const [];
  }

  @override
  Future<List<E>?> handleStorageUpdate(InternalStorageData update) async {
    if (!_matchesByPrefix(update)) return null;

    for (final id in update.updatedIds) {
      if (!_arrivedIds.contains(id)) {
        _arrivedIds.add(id);
      }
    }

    if (_arrivedIds.isEmpty) return const [];

    final allLocal = storage.querySync(req);
    final localById = <String, E>{};
    for (final m in allLocal) {
      localById[m.id] = m;
      localById[m.event.id] = m;
    }

    final ordered = <E>[];
    final seen = <String>{};
    for (final id in _arrivedIds) {
      final model = localById[id];
      if (model != null && seen.add(model.id)) {
        ordered.add(model);
      }
    }

    return ordered;
  }

  bool _matchesByPrefix(InternalStorageData update) {
    if (update.req == null) return false;
    return update.req!.subscriptionPrefix.startsWith(req.subscriptionPrefix);
  }
}

/// Local-and-remote source handler.
///
/// Queries local first (emits if non-empty), fires remote, then
/// refreshes from local on relevant storage updates.
final class LocalAndRemoteSourceHandler<E extends Model<dynamic>>
    extends SourceHandler<E> {
  final LocalAndRemoteSource source;
  final RemoteQueryBuffer _queryBuffer;

  /// Whether the EOSE/remote response has been received.
  bool eoseReceived = false;

  LocalAndRemoteSourceHandler(
      super.storage, super.req, super.subscriptionPrefix, this.source, this._queryBuffer);

  @override
  Future<List<E>> initialize() async {
    final local = storage.querySync(req);

    if (source.cachedFor != null && storage.isCacheValid(req, source.cachedFor!)) {
      eoseReceived = true;
      return local;
    }

    _fireRemoteQuery();

    return local;
  }

  Future<void> _fireRemoteQuery() async {
    await _queryBuffer.bufferQuery(req, source, subscriptionPrefix);
    storage.updateCacheTimestamp(req);
  }

  @override
  Future<List<E>?> handleStorageUpdate(InternalStorageData update) async {
    final isOurSubscription = _matchesByPrefix(update);
    final isGeneralUpdate = update.req == null;

    if (isOurSubscription) {
      eoseReceived = true;
    }

    if (isOurSubscription || isGeneralUpdate || _isRelevantUpdate(update)) {
      return refreshFromLocal();
    }

    return null;
  }

  bool _matchesByPrefix(InternalStorageData update) {
    if (update.req == null) return false;
    return update.req!.subscriptionPrefix.startsWith(req.subscriptionPrefix);
  }

  bool _isRelevantUpdate(InternalStorageData update) {
    if (update.updatedIds.isEmpty) return true;
    return true;
  }
}

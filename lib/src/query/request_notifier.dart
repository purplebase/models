import 'dart:async';

import 'package:riverpod/riverpod.dart';

import '../core/model.dart';
import '../filter/request.dart';
import '../source/source.dart';
import '../source/remote_source.dart';
import '../source/local_and_remote_source.dart';
import '../storage/storage_notifier.dart';
import '../storage/storage_state.dart';
import 'query_phase.dart';
import 'source_handler.dart';
import 'nested_query_manager.dart';
import 'remote_query_buffer.dart';

/// A request notifier that takes a [Request] and manages the lifecycle
/// of querying and filtering incoming events from [StorageNotifier].
///
/// Uses an explicit [QueryPhase] state machine instead of boolean guards.
/// Microtask coalescing ensures no updates are silently dropped.
class RequestNotifier<E extends Model<dynamic>>
    extends StateNotifier<StorageState<E>> {
  final Ref ref;
  final Request<E> req;
  final Source source;
  final StorageNotifier storage;

  /// Current query phase.
  QueryPhase _phase = QueryPhase.initializing;
  QueryPhase get phase => _phase;

  late final SourceHandler<E> _sourceHandler;
  late final NestedQueryManager _nestedManager;

  /// Microtask coalescing replaces _isRefreshing guard.
  bool _refreshScheduled = false;

  /// Guard: prevent re-entrant relationship processing.
  bool _isProcessingRelationships = false;

  /// Timer for responseTimeout enforcement.
  Timer? _responseTimeoutTimer;

  /// The parent subscription ID for relationship queries.
  late final String _parentSubscriptionId;

  /// Exposed for testing.
  List<Request> get relationshipRequests =>
      _nestedManager.relationshipRequests;
  int get totalRelationshipQueriesIssued =>
      _nestedManager.totalRelationshipQueriesIssued;

  RequestNotifier(this.ref, this.req, Source? source)
      : storage = ref.read(storageNotifierProvider.notifier),
        source = source ??
            ref.read(storageNotifierProvider.notifier).config.defaultQuerySource,
        super(StorageLoading([])) {
    if (req.filters.isEmpty) return;

    _parentSubscriptionId = req.subscriptionId;

    final queryBuffer = getQueryBuffer(storage);

    _sourceHandler = SourceHandler.create(
      source: this.source,
      storage: storage,
      req: req,
      subscriptionPrefix: req.subscriptionPrefix,
      queryBuffer: queryBuffer,
    );

    _nestedManager = NestedQueryManager(
      storage: storage,
      parentSubscriptionId: _parentSubscriptionId,
      outerSource: this.source,
      queryBuffer: queryBuffer,
    );

    _startSubscription();
    _startResponseTimeout();
    _initialize();

    ref.onDispose(() async {
      _responseTimeoutTimer?.cancel();
      _phase = QueryPhase.disposed;
      await storage.cancel(req);
      await _nestedManager.dispose();
    });
  }

  void _startSubscription() {
    ref.listen<StorageState>(storageNotifierProvider, (previous, next) {
      if (next is InternalStorageData) {
        _handleStorageUpdate(next);
      }
    });
  }

  void _startResponseTimeout() {
    if (source is! RemoteSource) return;

    _responseTimeoutTimer = Timer(storage.config.responseTimeout, () {
      if (!mounted) return;
      if (_phase == QueryPhase.awaitingRemote ||
          _phase == QueryPhase.initializing) {
        _transition(QueryPhase.live, state.models);
      }
    });
  }

  Future<void> _initialize() async {
    try {
      final models = await _sourceHandler.initialize();

      if (!mounted) return;

      switch (source) {
        case LocalSource():
          _transition(QueryPhase.live, models);
          _processRelationships(models);

        case LocalAndRemoteSource():
          if ((_sourceHandler as LocalAndRemoteSourceHandler).eoseReceived) {
            _transition(QueryPhase.live, models);
            _processRelationships(models);
          } else {
            if (models.isNotEmpty) {
              _emit(models);
              _processRelationships(models);
            }
            _transition(QueryPhase.awaitingRemote, state.models);
          }

        case RemoteSource(:final stream) when !stream:
          _cancelResponseTimeout();
          _transition(QueryPhase.live, models);
          _processRelationships(models);

        case RemoteSource():
          _transition(QueryPhase.awaitingRemote, state.models);
      }
    } catch (e, stack) {
      if (mounted) {
        _phase = QueryPhase.error;
        state = StorageError(state.models, exception: e, stackTrace: stack);
      }
    }
  }

  void _handleStorageUpdate(InternalStorageData update) {
    if (!mounted || _phase == QueryPhase.disposed) return;

    // Check if this is a relationship update
    if (_nestedManager.isRelationshipUpdate(update.req)) {
      _scheduleRefresh();
      return;
    }

    _sourceHandler.handleStorageUpdate(update).then((models) {
      if (!mounted) return;

      // For streaming/live queries, handle general save updates even when
      // the source handler returns null (e.g., RemoteSourceHandler only
      // tracks subscription-prefixed updates, but saves have null req)
      if (models == null) {
        if ((_phase == QueryPhase.streaming || _phase == QueryPhase.live) &&
            update.req == null) {
          final refreshed = _sourceHandler.refreshFromLocal();
          _emit(refreshed);
          _processRelationships(refreshed);
        }
        return;
      }

      if (_phase == QueryPhase.awaitingRemote) {
        bool shouldTransition = false;

        if (_sourceHandler is LocalAndRemoteSourceHandler &&
            (_sourceHandler as LocalAndRemoteSourceHandler).eoseReceived) {
          shouldTransition = true;
        } else if (_sourceHandler is RemoteSourceHandler) {
          shouldTransition = true;
        }

        if (shouldTransition) {
          _transition(QueryPhase.live, models);
          _cancelResponseTimeout();
          _processRelationships(models);
          _maybeStartStreaming();
          return;
        }
      }

      _emit(models);
      _processRelationships(models);

      // Re-process pending and-callbacks when general data arrives
      if (update.req == null && _nestedManager.hasPendingCallbacks) {
        _nestedManager.reprocessPendingCallbacks();
      }
    });
  }

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    scheduleMicrotask(() {
      _refreshScheduled = false;
      if (!mounted) return;
      final models = _sourceHandler.refreshFromLocal();
      _emit(models);
      _processRelationships(models);
    });
  }

  void _transition(QueryPhase newPhase, List<E> models) {
    if (!mounted) return;
    assert(
      isValidTransition(_phase, newPhase),
      'Invalid transition: $_phase → $newPhase',
    );
    _phase = newPhase;
    _emit(models);
  }

  void _emit(List<E> models) {
    if (!mounted) return;

    // Apply client-side filters
    var filtered = models;
    for (final filter in req.filters) {
      if (filter.where != null) {
        filtered = filtered.where((m) => filter.where!(m)).toList();
      }
    }

    switch (_phase) {
      case QueryPhase.initializing:
      case QueryPhase.awaitingRemote:
        state = StorageLoading(filtered);
      case QueryPhase.live:
      case QueryPhase.streaming:
        state = StorageData(filtered);
      case QueryPhase.error:
        break;
      case QueryPhase.disposed:
        break;
    }
  }

  void _cancelResponseTimeout() {
    _responseTimeoutTimer?.cancel();
    _responseTimeoutTimer = null;
  }

  void _maybeStartStreaming() {
    if (source is RemoteSource && (source as RemoteSource).stream) {
      if (_phase == QueryPhase.live) {
        _phase = QueryPhase.streaming;
      }
    }
  }

  void _processRelationships(List<E> models) {
    if (_isProcessingRelationships) return;
    _isProcessingRelationships = true;

    try {
      final andFns = req.filters.map((f) => f.and).nonNulls.toList();
      _nestedManager.processModels(models, andFns);
    } finally {
      _isProcessingRelationships = false;
    }
  }
}

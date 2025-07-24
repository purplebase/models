part of models;

/// Reactive storage with dummy data using internal relay backend
class DummyStorageNotifier extends StorageNotifier {
  final Ref ref;
  late NostrRelay _relay;

  DummyStorageNotifier(this.ref);

  final Map<RequestFilter, Timer> _streamingTimers = {};
  final Set<String> _streamingRequestIds =
      {}; // Track which requests are streaming
  final Map<String, ProviderSubscription> _relaySubscriptions = {};

  @override
  Future<void> initialize(StorageConfiguration config) async {
    if (isInitialized) return;

    await super.initialize(config);
    _relay = ref.read(relayProvider);
    isInitialized = true;
  }

  @override
  Future<bool> save(Set<Model<dynamic>> models) async {
    // Store using relay publish API
    final eventMaps = models.map((model) => model.event.toMap()).toList();
    final results = _relay.publish(eventMaps);

    // Check if all succeeded
    final allSucceeded = results.every((result) => result.startsWith('OK:'));

    // Handle NWC requests by generating dummy responses (run in background)
    for (final model in models) {
      if (model.event.kind == 23194) {
        _relay._handleNwcRequest(model.event.toMap());
      }
    }

    // Intentionally ignore config.keepMaxModels - dummy implementation don't care

    if (mounted && models.isNotEmpty) {
      final updatedIds = {for (final e in models) e.id};
      state = InternalStorageData(req: null, updatedIds: updatedIds);
    }

    return allSucceeded;
  }

  @override
  Future<PublishResponse> publish(
    Set<Model<dynamic>> models, {
    RemoteSource source = const RemoteSource(),
  }) async {
    // First save the models (this publishes to relay)
    // TODO: This is fucking wrong
    await save(models);

    final response = PublishResponse();

    if (models.isNotEmpty) {
      final relayUrls = config.getRelays(source: source);
      for (final relayUrl in relayUrls) {
        for (final model in models) {
          // Other events succeed as normal
          final message =
              'Fake publishing ${models.length} models to $relayUrl';
          response.addEvent(
            model.event.id,
            relayUrl: relayUrl,
            accepted: true,
            message: message,
          );
        }
      }
    }
    return response;
  }

  @override
  Future<List<E>> query<E extends Model<dynamic>>(
    Request<E> req, {
    Source? source,
  }) async {
    source ??= config.defaultQuerySource;

    // Always start with local results from relay subscription
    final results = querySync(req);

    // For LocalSource, return only local results
    if (source is LocalSource) {
      return results;
    }

    // For RemoteSource, handle streaming if enabled
    if (source is RemoteSource && source.stream) {
      // Mark this request as streaming (remove limits for future queries)
      final requestId = req.toString();
      _streamingRequestIds.add(requestId);

      // Set up reactive listening to relay subscription changes
      _setupRelaySubscriptionListener(req);

      // Start streaming simulation for each filter
      for (final filter in req.filters) {
        _startStreamingForFilter(filter, source);
      }
    }

    return results;
  }

  @override
  List<E> querySync<E extends Model<dynamic>>(Request<E> req) {
    // Create a subscription to get events from relay
    final relayRequest = Request(
      req.filters
          .map(
            (f) => RequestFilter(
              ids: f.ids,
              authors: f.authors,
              kinds: f.kinds,
              tags: f.tags,
              since: f.since,
              until: f.until,
              limit: f.limit,
              search: f.search,
            ),
          )
          .toList(),
    );

    // Get subscription notifier (this creates the subscription)
    final subscriptionNotifier = ref.read(
      relaySubscriptionProvider(relayRequest),
    );

    // Get current events from the subscription
    List<Map<String, dynamic>> relayEvents = subscriptionNotifier.events;

    // If we have no events in subscription but relay has events,
    // force a fresh query directly from relay storage
    if (relayEvents.isEmpty && _relay.storage.eventCount > 0) {
      relayEvents = _relay.storage.queryEvents(relayRequest.filters);
    }

    final allResults = <E>[];
    final subId = req.subscriptionId;
    final isStreaming = _streamingRequestIds.contains(subId);

    for (final filter in req.filters) {
      // Handle replaceable IDs by converting them to regular filters
      final replaceableIds = filter.ids.where((id) => id.contains(':')).toSet();

      List<E> results = [];

      // Convert relay events to models
      final models = relayEvents
          .map((event) {
            final constructor = Model.getConstructorForKind(event['kind']);
            if (constructor == null) return null;

            // Apply transformMap before constructing the model
            final transformedEvent = _applyTransformMap(event, ref);
            return constructor(transformedEvent, ref) as Model;
          })
          .whereType<E>()
          .toList();

      results.addAll(models);

      // Handle replaceable IDs (these are addressable IDs, not event IDs)
      if (replaceableIds.isNotEmpty) {
        for (final addressableId in replaceableIds) {
          // Parse addressable ID to get kind, pubkey, and d-tag
          final parts = addressableId.split(':');
          if (parts.length >= 3) {
            final kind = int.tryParse(parts[0]);
            final pubkey = parts[1];
            final dTag = parts.length > 3 ? parts[3] : '';

            if (kind != null) {
              final replaceableRequest = Request([
                RequestFilter(
                  kinds: {kind},
                  authors: {pubkey},
                  tags: dTag.isNotEmpty
                      ? {
                          '#d': {dTag},
                        }
                      : null,
                ),
              ]);

              // Query directly from relay storage for replaceable events
              final events = _relay.storage.queryEvents(
                replaceableRequest.filters,
              );

              final models = events
                  .map((event) {
                    final constructor = Model.getConstructorForKind(
                      event['kind'],
                    );
                    if (constructor == null) return null;

                    // Apply transformMap before constructing the model
                    final transformedEvent = _applyTransformMap(event, ref);
                    return constructor(transformedEvent, ref) as Model;
                  })
                  .whereType<E>()
                  .toList();

              results.addAll(models);
            }
          }
        }
      }

      // Apply custom where clause if present
      if (filter.where != null) {
        results = results.where((m) => filter.where!(m)).toList();
      }

      // Sort and apply limit per filter
      if (results.isNotEmpty) {
        // Sort by created_at descending, then by id ascending for ties (Nostr standard)
        results.sort((a, b) {
          final timeComparison = b.event.createdAt.compareTo(a.event.createdAt);
          if (timeComparison != 0) return timeComparison;
          return a.event.id.compareTo(b.event.id);
        });

        // Apply limit if specified and not streaming
        if (!isStreaming &&
            filter.limit != null &&
            results.length > filter.limit!) {
          results = results.take(filter.limit!).toList();
        }
      }

      allResults.addAll(results);
    }

    // Remove duplicates while preserving order
    // For replaceable events, deduplicate by addressable ID and keep the newest
    final seenIds = <String>{};
    final seenAddressableIds = <String, E>{};
    final finalResults = <E>[];

    for (final model in allResults) {
      if (model is ReplaceableModel) {
        final addressableId = model.id;
        final existing = seenAddressableIds[addressableId];

        if (existing == null) {
          // First time seeing this addressable ID
          seenAddressableIds[addressableId] = model;
          finalResults.add(model);
        } else {
          // We've seen this addressable ID before, keep the newer one
          if (model.event.createdAt.isAfter(existing.event.createdAt) ||
              (model.event.createdAt == existing.event.createdAt &&
                  model.event.id.compareTo(existing.event.id) > 0)) {
            // Replace the existing model with the newer one
            final index = finalResults.indexOf(existing);
            if (index != -1) {
              finalResults[index] = model;
            }
            seenAddressableIds[addressableId] = model;
          }
          // If existing is newer, keep it and don't add the current model
        }
      } else {
        // For non-replaceable events, use the regular event ID deduplication
        if (!seenIds.contains(model.event.id)) {
          seenIds.add(model.event.id);
          finalResults.add(model);
        } else {
          // Already seen this event ID, skip it
        }
      }
    }

    return finalResults;
  }

  /// Apply transformMap to an event before constructing a model
  Map<String, dynamic> _applyTransformMap(Map<String, dynamic> event, Ref ref) {
    // Apply signature stripping based on storage configuration
    if (!config.keepSignatures) {
      event['sig'] = null;
    }
    return event;
  }

  /// Set up reactive listening to relay subscription for streaming queries
  void _setupRelaySubscriptionListener<E extends Model<dynamic>>(
    Request<E> req,
  ) {
    final requestKey = req.toString();

    // Avoid duplicate subscriptions
    if (_relaySubscriptions.containsKey(requestKey)) {
      return;
    }

    // Create relay request
    final relayRequest = Request(
      req.filters
          .map(
            (f) => RequestFilter(
              ids: f.ids,
              authors: f.authors,
              kinds: f.kinds,
              tags: f.tags,
              since: f.since,
              until: f.until,
              limit: f.limit,
              search: f.search,
            ),
          )
          .toList(),
    );

    // Listen to relay subscription changes
    final subscription = ref.listen(relaySubscriptionProvider(relayRequest), (
      previous,
      current,
    ) {
      // Only notify if we have new events and are still mounted
      if (mounted &&
          current.events.isNotEmpty &&
          (previous == null ||
              current.events.length > previous.events.length)) {
        // Trigger a state update to notify listeners
        final updatedIds = <String>{};
        for (final event in current.events) {
          updatedIds.add(event['id'] as String);
        }
        state = InternalStorageData(req: null, updatedIds: updatedIds);
      }
    });

    _relaySubscriptions[requestKey] = subscription;
  }

  /// Starts streaming simulation for a specific filter
  void _startStreamingForFilter(RequestFilter filter, RemoteSource source) {
    // Cancel existing streaming for this filter
    _streamingTimers[filter]?.cancel();

    // For tests (when streamingBufferWindow is Duration.zero),
    // simulate streaming with immediate single model additions
    if (config.streamingBufferWindow == Duration.zero) {
      // Schedule small incremental additions for test predictability
      _simulateTestStreaming(filter);
      return;
    }

    // Generate new events periodically that match the filter
    _streamingTimers[filter] = Timer.periodic(config.streamingBufferWindow, (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        _streamingTimers.remove(filter);
        return;
      }

      final r = Random();
      // 30% chance to generate a new event each interval
      if (r.nextDouble() < 0.3) {
        // Note: In real implementation, this would receive events from external sources
        // For now, we don't generate fake streaming data - that should come from test utilities
      }
    });
  }

  /// Simulates streaming for tests by adding models with delays
  void _simulateTestStreaming(RequestFilter filter) {
    int count = 0;
    final timer = Timer.periodic(Duration(milliseconds: 10), (timer) async {
      if (!mounted) {
        timer.cancel();
        _streamingTimers.remove(filter);
        return;
      }
      if (count >= 3) {
        timer.cancel();
        _streamingTimers.remove(filter);
        return;
      }
      count++;
      // Note: In real implementation, this would receive events from external sources
      // For now, we don't generate fake streaming data - that should come from test utilities
    });
    _streamingTimers[filter] = timer;
  }

  @override
  Future<void> clear([Request? req]) async {
    if (req == null) {
      // Clear all events
      _relay.deleteEvents();

      // Cancel all streaming timers
      for (final timer in _streamingTimers.values) {
        timer.cancel();
      }
      _streamingTimers.clear();
      _streamingRequestIds.clear();

      // Dispose all relay subscriptions
      for (final subscription in _relaySubscriptions.values) {
        subscription.close();
      }
      _relaySubscriptions.clear();

      // Notify of state change
      if (mounted) {
        state = InternalStorageData(req: null, updatedIds: <String>{});
      }
      return;
    }

    // Query matching events and remove them by ID
    final matchingModels = querySync(req);
    final eventIdsToDelete = matchingModels
        .map((model) => model.event.id)
        .toSet();

    if (eventIdsToDelete.isNotEmpty) {
      _relay.deleteEvents(eventIdsToDelete);

      // Force refresh of all subscription caches by disposing and recreating them
      final subscriptionsToRecreate = <String, Request>{};
      for (final entry in _relaySubscriptions.entries) {
        final requestKey = entry.key;
        final subscription = entry.value;

        // Find the original request for this subscription
        // We need to extract it from the subscription state
        // For now, we'll just dispose the subscription and let it be recreated on next query
        subscription.close();
        subscriptionsToRecreate[requestKey] = Request([RequestFilter()]);
      }
      _relaySubscriptions.clear();

      // Clear streaming state for deleted events
      final updatedIds = <String>{};
      for (final id in eventIdsToDelete) {
        updatedIds.add(id);
      }

      // Force a state update to trigger re-queries
      if (mounted) {
        state = InternalStorageData(req: null, updatedIds: updatedIds);
      }
    }
  }

  @override
  Future<void> obliterate() async {
    // Same as clear with no request - delete all events
    await clear();
  }

  @override
  Future<void> cancel([Request? req]) async {
    if (req == null) {
      for (final timer in _streamingTimers.values) {
        timer.cancel();
      }
      _streamingTimers.clear();
      return;
    }

    for (final filter in req.filters) {
      _streamingTimers[filter]?.cancel();
      _streamingTimers.remove(filter);
    }
  }
}

part of models;

/// Pure in-memory storage for testing with streaming simulation.
///
/// Fast, isolated, and supports parallel test execution.
/// Simulates relay streaming by tracking subscriptions and pushing
/// matching events when saved.
class DummyStorageNotifier extends StorageNotifier {
  final List<Map<String, dynamic>> _events = [];

  /// Active streaming subscriptions: subscriptionId -> Request
  final Map<String, Request> _subscriptions = {};

  DummyStorageNotifier(super.ref);

  @override
  Future<void> initialize(StorageConfiguration config) async {
    if (isInitialized) return;
    await super.initialize(config);
    isInitialized = true;
  }

  @override
  Future<bool> save(Set<Model<dynamic>> models) async {
    if (models.isEmpty) return true;

    invalidateQueryCache();

    final savedEvents = <Map<String, dynamic>>[];

    for (final model in models) {
      final map = model.toMap();
      map['sig'] ??= Utils.generateRandomHex64() + Utils.generateRandomHex64();
      _addEvent(map);
      savedEvents.add(map);
    }

    if (!mounted) return true;

    // Collect all updates first to avoid concurrent modification
    // when listeners modify _subscriptions
    final updates = <InternalStorageData>[];

    // Simulate streaming: notify subscriptions that match the saved events
    for (final entry in _subscriptions.entries.toList()) {
      final req = entry.value;

      final matchingIds = <String>{};
      for (final event in savedEvents) {
        if (_eventMatchesRequest(event, req)) {
          // Use addressable ID for replaceable events, event ID otherwise
          final addressableId = _computeAddressableId(event);
          matchingIds.add(addressableId ?? event['id'] as String);
        }
      }

      if (matchingIds.isNotEmpty) {
        updates.add(InternalStorageData(req: req, updatedIds: matchingIds));
      }
    }

    // Add general update for non-streaming queries
    updates.add(
      InternalStorageData(
        req: null,
        updatedIds: {for (final model in models) model.id},
      ),
    );

    // Emit all updates
    for (final update in updates) {
      if (!mounted) return true;
      state = update;
    }

    return true;
  }

  void _addEvent(Map<String, dynamic> event) {
    final kind = event['kind'] as int;
    final pubkey = event['pubkey'] as String;

    if (Utils.isEventReplaceable(kind)) {
      // Remove older version of replaceable event
      String? dTag;
      if (kind >= 30000 && kind < 40000) {
        final tags = event['tags'] as List?;
        if (tags != null) {
          for (final tag in tags) {
            if (tag is List && tag.isNotEmpty && tag[0] == 'd') {
              dTag = tag.length > 1 ? tag[1] as String : '';
              break;
            }
          }
        }
      }

      _events.removeWhere((existing) {
        if (existing['kind'] != kind || existing['pubkey'] != pubkey) {
          return false;
        }
        if (kind >= 30000 && kind < 40000) {
          // Parameterized replaceable - match by d tag
          String? existingDTag;
          final existingTags = existing['tags'] as List?;
          if (existingTags != null) {
            for (final tag in existingTags) {
              if (tag is List && tag.isNotEmpty && tag[0] == 'd') {
                existingDTag = tag.length > 1 ? tag[1] as String : '';
                break;
              }
            }
          }
          return existingDTag == dTag;
        }
        // Regular replaceable (0, 3, 10000-19999)
        return true;
      });
    } else {
      // Regular event - just remove duplicates
      _events.removeWhere((e) => e['id'] == event['id']);
    }

    _events.add(Map<String, dynamic>.from(event));
  }

  @override
  Future<PublishResponse> publish(
    Set<Model<dynamic>> models, {
    RemoteSource source = const RemoteSource(),
  }) async {
    final response = PublishResponse();
    final relayUrls = await resolveRelays(source.relays);
    for (final relay in relayUrls) {
      for (final model in models) {
        response.addEvent(
          model.id,
          relayUrl: relay,
          accepted: true,
          message: 'Published via dummy storage',
        );
      }
    }
    await save(models);
    return response;
  }

  @override
  Future<List<E>> query<E extends Model<dynamic>>(
    Request<E> req, {
    Source? source,
    String? subscriptionPrefix,
  }) async {
    // Register subscription for streaming if enabled
    // This applies to both RemoteSource and LocalAndRemoteSource (which extends RemoteSource)
    if (source is RemoteSource && source.stream) {
      _subscriptions[req.subscriptionId] = req;
    }

    return querySync(req);
  }

  @override
  List<E> querySync<E extends Model<dynamic>>(Request<E> req) {
    return _materialize(req);
  }

  /// Check if an event matches a request's filters
  bool _eventMatchesRequest(Map<String, dynamic> event, Request req) {
    for (final filter in req.filters) {
      if (_eventMatchesFilter(event, filter)) return true;
    }
    return false;
  }

  /// Check if an event matches a single filter
  bool _eventMatchesFilter(Map<String, dynamic> event, RequestFilter filter) {
    final kind = event['kind'] as int;
    final pubkey = event['pubkey'] as String;
    final eventId = event['id'] as String;

    if (filter.ids.isNotEmpty) {
      final addressableId = _computeAddressableId(event);
      final matchesRawId = filter.ids.contains(eventId);
      final matchesAddressable =
          addressableId != null && filter.ids.contains(addressableId);
      if (!matchesRawId && !matchesAddressable) {
        return false;
      }
    }
    if (filter.authors.isNotEmpty && !filter.authors.contains(pubkey)) {
      return false;
    }
    if (filter.kinds.isNotEmpty && !filter.kinds.contains(kind)) {
      return false;
    }
    if (filter.tags.isNotEmpty) {
      final eventTags = event['tags'] as List?;
      if (eventTags == null) return false;
      for (final entry in filter.tags.entries) {
        final tagKey = entry.key.startsWith('#')
            ? entry.key.substring(1)
            : entry.key;
        final tagValues = entry.value;
        final hasMatch = eventTags.any(
          (t) =>
              t is List &&
              t.isNotEmpty &&
              t[0] == tagKey &&
              t.length > 1 &&
              tagValues.contains(t[1]),
        );
        if (!hasMatch) return false;
      }
    }
    if (filter.since != null) {
      final createdAt = event['created_at'] as int;
      if (createdAt < filter.since!.millisecondsSinceEpoch ~/ 1000) {
        return false;
      }
    }
    if (filter.until != null) {
      final createdAt = event['created_at'] as int;
      if (createdAt > filter.until!.millisecondsSinceEpoch ~/ 1000) {
        return false;
      }
    }
    return true;
  }

  List<E> _materialize<E extends Model<dynamic>>(Request<E> req) {
    final results = <E>[];

    for (final filter in req.filters) {
      var filtered = _events.where(
        (event) => _eventMatchesFilter(event, filter),
      );

      // Apply schemaFilter before model construction
      // Events rejected by schemaFilter are deleted from local storage
      if (filter.schemaFilter != null) {
        final schemaFilter = filter.schemaFilter!;
        final rejectedIds = <String>{};
        final accepted = <Map<String, dynamic>>[];

        for (final event in filtered) {
          if (schemaFilter(event)) {
            accepted.add(event);
          } else {
            rejectedIds.add(event['id'] as String);
          }
        }

        // Delete rejected events from storage
        if (rejectedIds.isNotEmpty) {
          _events.removeWhere((e) => rejectedIds.contains(e['id']));
          invalidateQueryCache();
        }

        filtered = accepted;
      }

      var models = filtered
          .map((event) {
            final constructor = Model.getConstructorForKind(event['kind']);
            if (constructor == null) return null;
            final transformed = _applyTransformMap(event);
            return constructor(transformed, ref) as Model;
          })
          .whereType<E>()
          .toList();

      if (filter.where != null) {
        models = models.where((m) => filter.where!(m)).toList();
      }

      models.sort((a, b) {
        final cmp = b.event.createdAt.compareTo(a.event.createdAt);
        if (cmp != 0) return cmp;
        return a.event.id.compareTo(b.event.id);
      });

      if (filter.limit != null && models.length > filter.limit!) {
        models = models.take(filter.limit!).toList();
      }

      results.addAll(models);
    }

    // Dedupe
    final seenIds = <String>{};
    final seenReplaceable = <String, E>{};
    final deduped = <E>[];

    for (final model in results) {
      if (model is ReplaceableModel) {
        final addressable = model.id;
        final existing = seenReplaceable[addressable];
        if (existing == null) {
          seenReplaceable[addressable] = model;
          deduped.add(model);
        } else if (model.event.createdAt.isAfter(existing.event.createdAt) ||
            (model.event.createdAt == existing.event.createdAt &&
                model.event.id.compareTo(existing.event.id) > 0)) {
          final index = deduped.indexOf(existing);
          if (index != -1) deduped[index] = model;
          seenReplaceable[addressable] = model;
        }
      } else {
        if (seenIds.add(model.event.id)) {
          deduped.add(model);
        }
      }
    }

    return deduped;
  }

  Map<String, dynamic> _applyTransformMap(Map<String, dynamic> event) {
    if (!config.keepSignatures) {
      final copy = Map<String, dynamic>.from(event);
      copy['sig'] = null;
      return copy;
    }
    return event;
  }

  /// Compute the addressable ID for replaceable events (kind:pubkey:d-tag).
  String? _computeAddressableId(Map<String, dynamic> event) {
    final kind = event['kind'] as int;
    if (!Utils.isEventReplaceable(kind)) return null;

    final pubkey = event['pubkey'] as String;

    if (kind >= 30000 && kind < 40000) {
      // Parameterized replaceable - include d tag
      String dTag = '';
      final tags = event['tags'] as List?;
      if (tags != null) {
        for (final tag in tags) {
          if (tag is List && tag.isNotEmpty && tag[0] == 'd') {
            dTag = tag.length > 1 ? tag[1] as String : '';
            break;
          }
        }
      }
      return '$kind:$pubkey:$dTag';
    }

    // Regular replaceable (0, 3, 10000-19999)
    return '$kind:$pubkey:';
  }

  @override
  Future<void> clear([Request? req]) async {
    invalidateQueryCache();

    if (req == null) {
      _events.clear();
      _subscriptions.clear();
      if (mounted) {
        state = InternalStorageData(req: null, updatedIds: {});
      }
      return;
    }

    final matching = querySync(req);
    if (matching.isEmpty) return;

    final idsToRemove = matching.map((m) => m.event.id).toSet();
    _events.removeWhere((e) => idsToRemove.contains(e['id']));

    if (mounted) {
      state = InternalStorageData(req: null, updatedIds: idsToRemove);
    }
  }

  @override
  Future<void> obliterate() async {
    await clear();
  }

  @override
  Future<void> cancel([Request? req]) async {
    if (req != null) {
      _subscriptions.remove(req.subscriptionId);
    } else {
      _subscriptions.clear();
    }
  }

  @override
  void dispose() {
    _events.clear();
    _subscriptions.clear();
    super.dispose();
  }
}

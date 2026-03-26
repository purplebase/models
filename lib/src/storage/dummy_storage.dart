import 'dart:async';

import '../core/model.dart';
import '../filter/request.dart';
import '../filter/request_filter.dart';
import '../source/source.dart';
import '../source/remote_source.dart';
import '../utils/utils.dart';
import 'storage_notifier.dart';
import 'storage_state.dart';
import 'storage_configuration.dart';

/// Pure in-memory storage for testing.
///
/// No relay simulation. No subscription tracking.
/// Tests model logic, relationship resolution, filter matching,
/// and state transitions — not relay behavior.
class DummyStorageNotifier extends StorageNotifier {
  final Map<String, Map<String, dynamic>> _events = {};

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
    invalidateCacheForModels(models);

    final updatedIds = <String>{};

    for (final model in models) {
      final map = Map<String, dynamic>.from(model.toMap());
      map['sig'] ??= Utils.generateRandomHex64() + Utils.generateRandomHex64();
      _addEvent(map);
      updatedIds.add(model.id);
    }

    if (!mounted) return true;

    state = InternalStorageData(req: null, updatedIds: updatedIds);

    return true;
  }

  void _addEvent(Map<String, dynamic> event) {
    final kind = event['kind'] as int;
    final pubkey = event['pubkey'] as String;

    if (Utils.isEventReplaceable(kind)) {
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

      // Remove older version of replaceable event
      final keysToRemove = <String>[];
      for (final entry in _events.entries) {
        final existing = entry.value;
        if (existing['kind'] != kind || existing['pubkey'] != pubkey) continue;
        if (kind >= 30000 && kind < 40000) {
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
          if (existingDTag == dTag) keysToRemove.add(entry.key);
        } else {
          keysToRemove.add(entry.key);
        }
      }
      for (final key in keysToRemove) {
        _events.remove(key);
      }
    }

    final storageId = _computeAddressableId(event) ?? event['id'] as String;
    _events[storageId] = Map<String, dynamic>.from(event);
  }

  @override
  Future<PublishResponse> publish(
    Set<Model<dynamic>> models, {
    Source? source,
  }) async {
    final remoteSource = (source as RemoteSource?) ?? const RemoteSource();
    final response = PublishResponse();
    final relayUrls = await resolveRelays(remoteSource.relays);
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
    final results = querySync(req);

    // For any source with a remote component, emit InternalStorageData
    // to notify watchers (including RequestNotifier) that data is available.
    if (source is RemoteSource) {
      final matchingIds = <String>{};
      for (final model in results) {
        final addressableId = _computeAddressableId(model.toMap());
        matchingIds.add(addressableId ?? model.event.id);
      }
      final emitReq = subscriptionPrefix != null
          ? Request<E>(req.filters, subscriptionPrefix: subscriptionPrefix)
          : Request<E>(req.filters, subscriptionPrefix: req.subscriptionPrefix);
      scheduleMicrotask(() {
        if (mounted) {
          state = InternalStorageData(req: emitReq, updatedIds: matchingIds);
        }
      });
    }

    return results;
  }

  @override
  List<E> querySync<E extends Model<dynamic>>(Request<E> req) {
    return _materialize(req);
  }

  bool _eventMatchesFilter(Map<String, dynamic> event, RequestFilter filter) {
    final kind = event['kind'] as int;
    final pubkey = event['pubkey'] as String;
    final eventId = event['id'] as String;

    if (filter.ids.isNotEmpty) {
      final addressableId = _computeAddressableId(event);
      final matchesRawId = filter.ids.contains(eventId);
      final matchesAddressable =
          addressableId != null && filter.ids.contains(addressableId);
      if (!matchesRawId && !matchesAddressable) return false;
    }
    if (filter.authors.isNotEmpty && !filter.authors.contains(pubkey)) {
      return false;
    }
    if (filter.kinds.isNotEmpty && !filter.kinds.contains(kind)) return false;
    if (filter.tags.isNotEmpty) {
      final eventTags = event['tags'] as List?;
      if (eventTags == null) return false;
      for (final entry in filter.tags.entries) {
        final tagKey =
            entry.key.startsWith('#') ? entry.key.substring(1) : entry.key;
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
      var filtered = _events.values.where(
        (event) => _eventMatchesFilter(event, filter),
      );

      // Apply schemaFilter before model construction, deleting rejected events
      if (filter.schemaFilter != null) {
        final toDelete = <String>[];
        final accepted = <Map<String, dynamic>>[];
        for (final event in filtered) {
          if (filter.schemaFilter!(event)) {
            accepted.add(event);
          } else {
            toDelete.add(event['id'] as String);
          }
        }
        for (final id in toDelete) {
          _events.removeWhere((k, v) => v['id'] == id);
        }
        filtered = accepted;
      }

      var models = filtered
          .map((event) {
            final constructor =
                Model.getConstructorForKind(event['kind']);
            if (constructor == null) return null;
            final transformed = _applyTransformMap(event);
            return constructor(transformed, ref) as Model;
          })
          .whereType<E>()
          .toList();

      // Apply client-side where filter after model construction
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

  String? _computeAddressableId(Map<String, dynamic> event) {
    final kind = event['kind'] as int;
    if (!Utils.isEventReplaceable(kind)) return null;

    final pubkey = event['pubkey'] as String;

    if (kind >= 30000 && kind < 40000) {
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

    return '$kind:$pubkey:';
  }

  @override
  Future<void> clear([Request? req]) async {
    invalidateQueryCache();
    if (req == null) {
      _events.clear();
      if (mounted) {
        state = InternalStorageData(req: null, updatedIds: {});
      }
      return;
    }

    final matching = querySync(req);
    if (matching.isEmpty) return;

    final idsToRemove = matching.map((m) => m.event.id).toSet();
    _events.removeWhere((k, v) => idsToRemove.contains(v['id']));

    if (mounted) {
      state = InternalStorageData(req: null, updatedIds: idsToRemove);
    }
  }

  @override
  Future<void> obliterate() async {
    await clear();
  }

  @override
  Future<void> cancel(Request req) async {}

  @override
  Future<void> closeSubscriptions({required dynamic relays}) async {}

  @override
  void dispose() {
    _events.clear();
    super.dispose();
  }
}

part of models;

/// In-memory storage for Nostr events using raw JSON data
class MemoryStorage {
  final Map<String, Map<String, dynamic>> _events = {};
  final Map<String, Map<String, dynamic>> _replaceableEvents =
      {}; // pubkey:kind -&gt; event
  final Map<String, Map<String, dynamic>> _addressableEvents =
      {}; // kind:pubkey:d -&gt; event
  final Set<String> _deletedEvents = {};

  /// Safely converts a dynamic tags field to List of List of String
  List<List<String>> _safeTags(dynamic tags) {
    if (tags is List) {
      return tags
          .map(
            (e) => e is List ? e.map((v) => v.toString()).toList() : <String>[],
          )
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return <List<String>>[];
  }

  /// Stores an event, handling replaceable and addressable events
  bool storeEvent(Map<String, dynamic> event) {
    final kind = event['kind'] as int;
    final id = event['id'] as String;
    final pubkey = event['pubkey'] as String;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      (event['created_at'] as int) * 1000,
    );

    // Don't store ephemeral events (kind 20000-29999)
    if (kind >= 20000 && kind < 30000) {
      return true;
    }

    // Don't store if already deleted
    if (_deletedEvents.contains(id)) {
      return false;
    }

    // Handle deletion events (NIP-09)
    if (kind == 5) {
      _handleDeletion(event);
      return true;
    }

    // Handle replaceable events
    if (Utils.isEventReplaceable(kind)) {
      final key = kind >= 30000 && kind < 40000
          ? _getAddressableId(event) // Addressable events
          : '$kind:$pubkey:'; // Regular replaceable events

      if (key != null) {
        final existing = kind >= 30000 && kind < 40000
            ? _addressableEvents[key]
            : _replaceableEvents[key];

        // Only replace if newer (or same time but lower ID)
        if (existing == null) {
          // Store new event

          if (kind >= 30000 && kind < 40000) {
            _addressableEvents[key] = event;
          } else {
            _replaceableEvents[key] = event;
          }
          _events[id] = event;
          return true;
        } else {
          final existingCreatedAt = DateTime.fromMillisecondsSinceEpoch(
            (existing['created_at'] as int) * 1000,
          );
          final existingId = existing['id'] as String;

          if (createdAt.isAfter(existingCreatedAt) ||
              (createdAt.isAtSameMomentAs(existingCreatedAt) &&
                  (event['content'] as String).isEmpty) ||
              (createdAt.isAtSameMomentAs(existingCreatedAt) &&
                  (existing['content'] as String).isNotEmpty &&
                  (event['content'] as String).isNotEmpty &&
                  id.compareTo(existingId) > 0)) {
            // Remove old event from main storage
            _events.remove(existingId);

            // Store new event
            if (kind >= 30000 && kind < 40000) {
              _addressableEvents[key] = event;
            } else {
              _replaceableEvents[key] = event;
            }
            _events[id] = event;
            return true;
          }
          return false; // Older event, don't store
        }
      }
    }

    // Store regular event
    if (_events.containsKey(id)) {
      return false; // Duplicate
    }

    _events[id] = event;
    return true;
  }

  /// Handles event deletion (NIP-09)
  void _handleDeletion(Map<String, dynamic> deleteEvent) {
    final tags = deleteEvent['tags'] as List<List<String>>;
    final eventIds = tags
        .where((tag) => tag.isNotEmpty && tag[0] == 'e')
        .map((tag) => tag[1])
        .toSet();
    final deleteEventPubkey = deleteEvent['pubkey'] as String;
    final deleteEventKind = deleteEvent['kind'] as int;

    for (final eventId in eventIds) {
      final event = _events[eventId];
      if (event != null && event['pubkey'] == deleteEventPubkey) {
        _events.remove(eventId);
        _deletedEvents.add(eventId);

        // Also remove from replaceable/addressable maps
        final key = deleteEventKind >= 30000 && deleteEventKind < 40000
            ? _getAddressableId(event)
            : '$deleteEventKind:$deleteEventPubkey:';

        if (key != null) {
          if (deleteEventKind >= 30000 && deleteEventKind < 40000) {
            _addressableEvents.remove(key);
          } else {
            _replaceableEvents.remove(key);
          }
        }
      }
    }
  }

  /// Queries events based on RequestFilter
  List<Map<String, dynamic>> queryEvents(List<RequestFilter> filters) {
    final results = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    for (final filter in filters) {
      // Get events from main storage
      final matchingEvents = _events.values
          .where((event) => _matchesFilter(event, filter))
          .where((event) => !seenIds.contains(event['id'] as String))
          .toList();

      // Also get events from replaceable storage (for replaceable events)
      final replaceableEvents = _replaceableEvents.values
          .where((event) => _matchesFilter(event, filter))
          .where((event) => !seenIds.contains(event['id'] as String))
          .toList();

      // Also get events from addressable storage (for addressable events like CustomData)
      final addressableEvents = _addressableEvents.values
          .where((event) => _matchesFilter(event, filter))
          .where((event) => !seenIds.contains(event['id'] as String))
          .toList();

      // Combine all sets
      final allMatchingEvents = [
        ...matchingEvents,
        ...replaceableEvents,
        ...addressableEvents,
      ];

      // Sort by created_at descending, then by id ascending for ties
      allMatchingEvents.sort((a, b) {
        final aCreatedAt = DateTime.fromMillisecondsSinceEpoch(
          (a['created_at'] as int) * 1000,
        );
        final bCreatedAt = DateTime.fromMillisecondsSinceEpoch(
          (b['created_at'] as int) * 1000,
        );
        final timeComparison = bCreatedAt.compareTo(aCreatedAt);
        if (timeComparison != 0) return timeComparison;
        return (a['id'] as String).compareTo(b['id'] as String);
      });

      // Apply limit if specified
      final limitedEvents = filter.limit != null
          ? allMatchingEvents.take(filter.limit!).toList()
          : allMatchingEvents;

      for (final event in limitedEvents) {
        final eventId = event['id'] as String;
        if (!seenIds.contains(eventId)) {
          results.add(event);
          seenIds.add(eventId);
        }
      }
    }

    return results;
  }

  /// Checks if an event matches a RequestFilter
  bool _matchesFilter(Map<String, dynamic> event, RequestFilter filter) {
    final id = event['id'] as String;
    final pubkey = event['pubkey'] as String;
    final kind = event['kind'] as int;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      (event['created_at'] as int) * 1000,
    );
    final content = event['content'] as String;
    final tags = _safeTags(event['tags']);

    // Check IDs
    if (filter.ids.isNotEmpty && !filter.ids.contains(id)) {
      return false;
    }

    // Check authors
    if (filter.authors.isNotEmpty && !filter.authors.contains(pubkey)) {
      return false;
    }

    // Check kinds
    if (filter.kinds.isNotEmpty && !filter.kinds.contains(kind)) {
      return false;
    }

    // Check time range
    if (filter.since != null && createdAt.isBefore(filter.since!)) {
      return false;
    }

    if (filter.until != null && createdAt.isAfter(filter.until!)) {
      return false;
    }

    // Check tag filters
    if (filter.tags.isNotEmpty) {
      for (final entry in filter.tags.entries) {
        final tagName = entry.key.startsWith('#')
            ? entry.key.substring(1)
            : entry.key;
        final tagValues = entry.value;
        final eventTagValues = tags
            .where((tag) => tag.isNotEmpty && tag[0] == tagName)
            .map((tag) => tag[1])
            .toSet();

        // At least one tag value must match
        if (!tagValues.any((value) => eventTagValues.contains(value))) {
          return false;
        }
      }
    }

    // Check search (NIP-50) - simple regex-based full-text search
    if (filter.search != null && filter.search!.isNotEmpty) {
      final searchLower = filter.search!.toLowerCase();
      final contentLower = content.toLowerCase();

      // Simple contains check - could be enhanced with regex
      if (!contentLower.contains(searchLower)) {
        // Also search in tag values
        bool foundInTags = false;
        for (final tag in tags) {
          for (final tagValue in tag) {
            if (tagValue.toLowerCase().contains(searchLower)) {
              foundInTags = true;
              break;
            }
          }
          if (foundInTags) break;
        }
        if (!foundInTags) {
          return false;
        }
      }
    }

    return true;
  }

  /// Gets an event by ID
  Map<String, dynamic>? getEvent(String id) {
    return _events[id];
  }

  /// Gets the count of stored events
  int get eventCount => _events.length;

  /// Gets the count of deleted events
  int get deletedEventCount => _deletedEvents.length;

  /// Clears all stored events (for testing)
  void clear() {
    _events.clear();
    _replaceableEvents.clear();
    _addressableEvents.clear();
    _deletedEvents.clear();
  }

  /// Removes an event by ID from storage
  bool removeEvent(String eventId) {
    final event = _events[eventId];
    if (event == null) {
      return false;
    }

    _events.remove(eventId);
    _deletedEvents.add(eventId);

    // Also remove from replaceable/addressable maps if applicable
    final kind = event['kind'] as int;
    final pubkey = event['pubkey'] as String;

    if (Utils.isEventReplaceable(kind)) {
      final key = kind >= 30000 && kind < 40000
          ? _getAddressableId(event) // Addressable events
          : '$kind:$pubkey:'; // Regular replaceable events

      if (key != null) {
        if (kind >= 30000 && kind < 40000) {
          _addressableEvents.remove(key);
        } else {
          _replaceableEvents.remove(key);
        }
      }
    }

    return true;
  }

  /// Gets the addressable identifier for addressable events
  String? _getAddressableId(Map<String, dynamic> event) {
    final kind = event['kind'] as int;
    final pubkey = event['pubkey'] as String;
    final tags = _safeTags(event['tags']);

    if (kind >= 30000 && kind < 40000) {
      final dTag =
          tags
              .where((tag) => tag.isNotEmpty && tag[0] == 'd')
              .map((tag) => tag[1])
              .firstOrNull ??
          '';
      return '$kind:$pubkey:$dTag';
    }
    return null;
  }
}

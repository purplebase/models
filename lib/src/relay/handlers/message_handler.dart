part of models;

/// Handles WebSocket messages for the Nostr relay
class MessageHandler {
  final MemoryStorage storage;
  final Map<String, StreamSubscription> _subscriptions = {};
  final StreamController<List<dynamic>> _outgoingController =
      StreamController<List<dynamic>>.broadcast();

  MessageHandler(this.storage);

  /// Stream of outgoing messages to send to the client
  Stream<List<dynamic>> get outgoingMessages => _outgoingController.stream;

  /// Handles incoming message from client
  void handleMessage(String message) {
    try {
      final dynamic parsed = jsonDecode(message);
      if (parsed is! List || parsed.isEmpty) {
        _sendNotice('Invalid message format');
        return;
      }

      final messageType = parsed[0] as String;

      switch (messageType) {
        case 'EVENT':
          _handleEvent(parsed);
          break;
        case 'REQ':
          _handleReq(parsed);
          break;
        case 'CLOSE':
          _handleClose(parsed);
          break;
        case 'AUTH':
          _handleAuth(parsed);
          break;
        case 'COUNT':
          _handleCount(parsed);
          break;
        default:
          _sendNotice('Unknown message type: $messageType');
      }
    } catch (e) {
      _sendNotice('Error parsing message: $e');
    }
  }

  /// Handles EVENT messages
  void _handleEvent(List<dynamic> message) {
    if (message.length != 2) {
      _sendNotice('Invalid EVENT message format');
      return;
    }

    try {
      final event = message[1] as Map<String, dynamic>;

      // Validate event ID (basic validation)
      final computedId = _computeEventId(event);
      if (computedId != event['id']) {
        _sendOk(event['id'], false, 'invalid: event id does not match');
        return;
      }

      // Store the event
      final stored = storage.storeEvent(event);

      if (stored) {
        _sendOk(event['id'], true, '');
        // Broadcast to subscriptions
        _broadcastEvent(event);
      } else {
        _sendOk(event['id'], true, 'duplicate: already have this event');
      }
    } catch (e) {
      _sendNotice('Error processing EVENT: $e');
    }
  }

  /// Handles REQ messages
  void _handleReq(List<dynamic> message) {
    if (message.length < 2) {
      _sendNotice('Invalid REQ message format');
      return;
    }

    final subscriptionId = message[1] as String;

    // Close existing subscription if any
    _subscriptions[subscriptionId]?.cancel();

    try {
      // Parse filters
      final filters = <RequestFilter>[];
      for (int i = 2; i < message.length; i++) {
        final filterJson = message[i] as Map<String, dynamic>;
        filters.add(_jsonToRequestFilter(filterJson));
      }

      // Query existing events
      final events = storage.queryEvents(filters);

      // Send existing events
      for (final event in events) {
        _sendEvent(subscriptionId, event);
      }

      // Send EOSE
      _sendEose(subscriptionId);

      // Set up subscription for new events
      _subscriptions[subscriptionId] = _outgoingController.stream
          .where((msg) => msg[0] == 'BROADCAST_EVENT')
          .listen((msg) {
        final event = msg[1] as Map<String, dynamic>;
        for (final filter in filters) {
          if (_matchesFilter(event, filter)) {
            _sendEvent(subscriptionId, event);
            break;
          }
        }
      });
    } catch (e) {
      _sendClosed(subscriptionId, 'error: ${e.toString()}');
    }
  }

  /// Handles CLOSE messages
  void _handleClose(List<dynamic> message) {
    if (message.length != 2) {
      _sendNotice('Invalid CLOSE message format');
      return;
    }

    final subscriptionId = message[1] as String;
    _subscriptions[subscriptionId]?.cancel();
    _subscriptions.remove(subscriptionId);
  }

  /// Handles AUTH messages (NIP-42)
  void _handleAuth(List<dynamic> message) {
    // Basic AUTH handling - could be extended
    _sendNotice('AUTH not implemented');
  }

  /// Handles COUNT messages (NIP-45)
  void _handleCount(List<dynamic> message) {
    if (message.length < 3) {
      _sendNotice('Invalid COUNT message format');
      return;
    }

    final subscriptionId = message[1] as String;

    try {
      // Parse filters
      final filters = <RequestFilter>[];
      for (int i = 2; i < message.length; i++) {
        final filterJson = message[i] as Map<String, dynamic>;
        filters.add(_jsonToRequestFilter(filterJson));
      }

      // Count matching events
      final events = storage.queryEvents(filters);
      _sendCount(subscriptionId, events.length);
    } catch (e) {
      _sendClosed(subscriptionId, 'error: ${e.toString()}');
    }
  }

  /// Broadcasts an event to all active subscriptions
  void _broadcastEvent(Map<String, dynamic> event) {
    _outgoingController.add(['BROADCAST_EVENT', event]);
  }

  /// Sends an EVENT message
  void _sendEvent(String subscriptionId, Map<String, dynamic> event) {
    _outgoingController.add(['EVENT', subscriptionId, event]);
  }

  /// Sends an OK message
  void _sendOk(String eventId, bool success, String message) {
    _outgoingController.add(['OK', eventId, success, message]);
  }

  /// Sends an EOSE message
  void _sendEose(String subscriptionId) {
    _outgoingController.add(['EOSE', subscriptionId]);
  }

  /// Sends a CLOSED message
  void _sendClosed(String subscriptionId, String message) {
    _outgoingController.add(['CLOSED', subscriptionId, message]);
  }

  /// Computes the event ID according to NIP-01
  String _computeEventId(Map<String, dynamic> eventJson) {
    final serialized = _serializeForId(eventJson);
    final bytes = utf8.encode(serialized);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Serializes the event for ID computation according to NIP-01
  String _serializeForId(Map<String, dynamic> eventJson) {
    final array = [
      0,
      eventJson['pubkey'],
      eventJson['created_at'],
      eventJson['kind'],
      eventJson['tags'],
      eventJson['content']
    ];
    return jsonEncode(array);
  }

  /// Converts JSON to RequestFilter
  RequestFilter _jsonToRequestFilter(Map<String, dynamic> json) {
    final tags = <String, Set<String>>{};

    // Parse tag filters (keys starting with #)
    for (final entry in json.entries) {
      if (entry.key.startsWith('#') && entry.key.length == 2) {
        tags[entry.key] = (entry.value as List).cast<String>().toSet();
      }
    }

    return RequestFilter(
      ids: json['ids'] != null
          ? (json['ids'] as List).cast<String>().toSet()
          : null,
      authors: json['authors'] != null
          ? (json['authors'] as List).cast<String>().toSet()
          : null,
      kinds: json['kinds'] != null
          ? (json['kinds'] as List).cast<int>().toSet()
          : null,
      tags: tags.isNotEmpty ? tags : null,
      since: json['since'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['since'] * 1000)
          : null,
      until: json['until'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['until'] * 1000)
          : null,
      limit: json['limit'] as int?,
      search: json['search'] as String?,
    );
  }

  /// Checks if an event matches a RequestFilter
  bool _matchesFilter(Map<String, dynamic> event, RequestFilter filter) {
    // Check IDs
    if (filter.ids.isNotEmpty && !filter.ids.contains(event['id'])) {
      return false;
    }

    // Check authors
    if (filter.authors.isNotEmpty &&
        !filter.authors.contains(event['pubkey'])) {
      return false;
    }

    // Check kinds
    if (filter.kinds.isNotEmpty && !filter.kinds.contains(event['kind'])) {
      return false;
    }

    // Check time range
    final eventCreatedAt = DateTime.fromMillisecondsSinceEpoch(
        (event['created_at'] as int) * 1000);
    if (filter.since != null && eventCreatedAt.isBefore(filter.since!)) {
      return false;
    }

    if (filter.until != null && eventCreatedAt.isAfter(filter.until!)) {
      return false;
    }

    // Check tag filters
    if (filter.tags.isNotEmpty) {
      for (final entry in filter.tags.entries) {
        final tagName =
            entry.key.startsWith('#') ? entry.key.substring(1) : entry.key;
        final tagValues = entry.value;
        final eventTagValues = _getTagSetValues(event, tagName);

        // At least one tag value must match
        if (!tagValues.any((value) => eventTagValues.contains(value))) {
          return false;
        }
      }
    }

    // Check search (NIP-50) - simple regex-based full-text search
    if (filter.search != null && filter.search!.isNotEmpty) {
      final searchLower = filter.search!.toLowerCase();
      final contentLower = (event['content'] as String? ?? '').toLowerCase();

      // Simple contains check - could be enhanced with regex
      if (!contentLower.contains(searchLower)) {
        // Also search in tag values
        bool foundInTags = false;
        final tags = event['tags'] as List<List<String>>? ?? [];
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

  /// Closes all subscriptions and resources
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _outgoingController.close();
  }

  /// Sends a NOTICE message
  void _sendNotice(String message) {
    _outgoingController.add(['NOTICE', message]);
  }

  /// Sends a COUNT message
  void _sendCount(String subscriptionId, int count) {
    _outgoingController.add([
      'COUNT',
      subscriptionId,
      {'count': count},
    ]);
  }

  /// Helper method to get tag values from raw event JSON
  Set<String> _getTagSetValues(Map<String, dynamic> event, String tagName) {
    final tags = event['tags'] as List<List<String>>? ?? [];
    return tags
        .where((tag) => tag.isNotEmpty && tag[0] == tagName)
        .map((tag) => tag.length > 1 ? tag[1] : '')
        .where((value) => value.isNotEmpty)
        .toSet();
  }
}

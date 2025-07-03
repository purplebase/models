part of models;

/// Handles WebSocket messages for the Nostr relay
class MessageHandler {
  final MemoryStorage storage;
  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<WebSocket, StreamSubscription> _webSocketSubscriptions = {};

  // Track active subscriptions: subId -> (filters, websocket)
  final Map<String, _ActiveSubscription> _activeSubs = {};

  // Per-subscription versioning
  final Map<String, int> _subVersions = {};
  final Map<String, int> _closedVersions = {};

  // Track closed subscriptions to prevent race conditions
  final Set<String> _closedSubs = {};

  MessageHandler(this.storage);

  /// Handles incoming message from client
  void handleMessage(String message, WebSocket webSocket) {
    try {
      final data = jsonDecode(message) as List<dynamic>;
      final messageType = data[0] as String;

      // Process CLOSE messages immediately and synchronously
      if (messageType == 'CLOSE') {
        _handleClose(data, webSocket);
        return;
      }

      // Process other messages normally
      _processMessage(messageType, data, webSocket);
    } catch (e) {
      _sendError('Invalid message format: $e', webSocket);
    }
  }

  void _processMessage(
      String messageType, List<dynamic> data, WebSocket webSocket) {
    switch (messageType) {
      case 'EVENT':
        _handleEvent(data, webSocket);
        break;
      case 'REQ':
        _handleReq(data, webSocket);
        break;
      case 'AUTH':
        _handleAuth(data, webSocket);
        break;
      default:
        _sendError('Unknown message type: $messageType', webSocket);
    }
  }

  /// Handles EVENT messages
  void _handleEvent(List<dynamic> data, WebSocket webSocket) {
    if (data.length < 2) {
      _sendError('Invalid EVENT message', webSocket);
      return;
    }

    final event = data[1] as Map<String, dynamic>;
    final eventId = event['id'] as String;

    // Validate event format
    if (!_validateEvent(event)) {
      _sendError('Invalid event format', webSocket);
      return;
    }

    // Validate event ID (NIP-01)
    if (!_validateEventId(event)) {
      _sendError('Invalid event ID', webSocket);
      return;
    }

    // Store event
    storage.storeEvent(event);

    // Broadcast to active subscriptions (excluding closed ones)
    _broadcastEvent(event, webSocket);

    // Send OK response
    _sendOk(eventId, true, 'Event stored', webSocket);
  }

  /// Handles REQ messages
  void _handleReq(List<dynamic> data, WebSocket webSocket) {
    if (data.length < 3) {
      _sendError('Invalid REQ message', webSocket);
      return;
    }

    final subId = data[1] as String;
    final filters = <RequestFilter>[];

    // Parse filters - support both single filter and list of filters
    final filterData = data[2];
    if (filterData is Map<String, dynamic>) {
      // Single filter object
      filters.add(_jsonToRequestFilter(filterData));
    } else if (filterData is List) {
      // List of filter objects
      for (final filterJson in filterData) {
        if (filterJson is Map<String, dynamic>) {
          filters.add(_jsonToRequestFilter(filterJson));
        } else {
          _sendError('Invalid filter format in REQ', webSocket);
          return;
        }
      }
    } else {
      _sendError('Invalid filter format in REQ', webSocket);
      return;
    }

    // Increment version for this subId
    final newVersion = (_subVersions[subId] ?? 0) + 1;
    _subVersions[subId] = newVersion;

    // Remove from closed set if it was there
    _closedSubs.remove(subId);

    // Store subscription
    _activeSubs[subId] = _ActiveSubscription(filters, webSocket, newVersion);

    // Query and send matching events
    _sendMatchingEvents(subId, filters, webSocket, newVersion);
  }

  /// Handles CLOSE messages - processed immediately and synchronously
  void _handleClose(List<dynamic> data, WebSocket webSocket) {
    if (data.length < 2) {
      _sendError('Invalid CLOSE message', webSocket);
      return;
    }

    final subId = data[1] as String;

    // Mark as closed immediately
    _closedSubs.add(subId);
    _closedVersions[subId] = _subVersions[subId] ?? 0;

    // Remove from active subscriptions
    _activeSubs.remove(subId);

    // Send CLOSED acknowledgment
    _sendClosed(subId, 'subscription closed', webSocket);
  }

  /// Handles AUTH messages (NIP-42)
  void _handleAuth(List<dynamic> data, WebSocket webSocket) {
    // Basic AUTH handling - could be extended
    _sendError('AUTH not implemented', webSocket);
  }

  void _broadcastEvent(Map<String, dynamic> event, WebSocket webSocket) {
    final activeKeys = List<String>.from(_activeSubs.keys);
    print('DEBUG: _activeSubs: ${_activeSubs.keys}');
    print('DEBUG: _closedVersions: $_closedVersions');
    for (final subId in activeKeys) {
      final sub = _activeSubs[subId];
      if (sub == null) continue;
      final closedVersion = _closedVersions[subId] ?? -1;
      if (sub.version <= closedVersion) continue;
      if (sub.webSocket.readyState == WebSocket.open &&
          sub.filters.any((f) => storage._matchesFilter(event, f))) {
        _sendEvent(subId, event, sub.webSocket);
      }
    }
  }

  void _sendMatchingEvents(String subId, List<RequestFilter> filters,
      WebSocket webSocket, int version) {
    final events = storage.queryEvents(filters);

    for (final event in events) {
      final closedVersion = _closedVersions[subId] ?? -1;
      if (version <= closedVersion) break;
      if (!_closedSubs.contains(subId) && _activeSubs.containsKey(subId)) {
        _sendEvent(subId, event, webSocket);
      }
    }

    // Send EOSE
    if (version > (_closedVersions[subId] ?? -1)) {
      if (!_closedSubs.contains(subId) && _activeSubs.containsKey(subId)) {
        _sendEose(subId, webSocket);
      }
    }
  }

  void _sendEvent(
      String subId, Map<String, dynamic> event, WebSocket webSocket) {
    final message = jsonEncode(['EVENT', subId, event]);
    print('DEBUG: Sending EVENT: $message');
    webSocket.add(message);
  }

  void _sendEose(String subId, WebSocket webSocket) {
    final message = jsonEncode(['EOSE', subId]);
    print('DEBUG: Sending EOSE: $message');
    webSocket.add(message);
  }

  void _sendOk(
      String eventId, bool accepted, String message, WebSocket webSocket) {
    final response = jsonEncode(['OK', eventId, accepted, message]);
    print('DEBUG: Sending OK: $response');
    webSocket.add(response);
  }

  void _sendError(String error, WebSocket webSocket) {
    try {
      final response = jsonEncode(['ERROR', error]);
      print('DEBUG: Sending ERROR: $response');
      webSocket.add(response);
    } catch (e) {
      print('Failed to send error: $e');
    }
  }

  void _sendClosed(String subId, String message, WebSocket webSocket) {
    final response = jsonEncode(['CLOSED', subId, message]);
    print('DEBUG: Sending CLOSED: $response');
    webSocket.add(response);
  }

  bool _validateEvent(Map<String, dynamic> event) {
    // Basic validation - can be expanded
    return event.containsKey('id') &&
        event.containsKey('pubkey') &&
        event.containsKey('created_at') &&
        event.containsKey('kind') &&
        event.containsKey('content') &&
        event.containsKey('sig');
  }

  bool _validateEventId(Map<String, dynamic> event) {
    try {
      // Safely convert tags to List<List<String>>
      List<List<String>> safeTags;
      if (event['tags'] is List) {
        safeTags = (event['tags'] as List)
            .map((e) =>
                e is List ? e.map((v) => v.toString()).toList() : <String>[])
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        safeTags = <List<String>>[];
      }

      // Create the event data array as specified in NIP-01
      final eventData = [
        0, // event type
        event['pubkey'] as String,
        event['created_at'] as int,
        event['kind'] as int,
        safeTags,
        event['content'] as String
      ];

      // Serialize and hash
      final serialized = jsonEncode(eventData);
      final bytes = utf8.encode(serialized);
      final hash = sha256.convert(bytes);
      final computedId = hash.toString();
      final providedId = event['id'] as String;

      print('DEBUG: Event ID validation:');
      print('  Provided ID: $providedId');
      print('  Computed ID: $computedId');
      print('  Match: ${computedId == providedId}');

      // Compare with provided ID
      return computedId == providedId;
    } catch (e) {
      print('DEBUG: Event ID validation error: $e');
      return false;
    }
  }

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
    );
  }

  /// Closes all subscriptions and resources
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    for (final subscription in _webSocketSubscriptions.values) {
      subscription.cancel();
    }
    _webSocketSubscriptions.clear();
  }
}

class _ActiveSubscription {
  final List<RequestFilter> filters;
  final WebSocket webSocket;
  final int version;

  _ActiveSubscription(this.filters, this.webSocket, this.version);
}

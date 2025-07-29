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
    String messageType,
    List<dynamic> data,
    WebSocket webSocket,
  ) {
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

    // Handle NWC requests (kind 23194) by generating automatic responses
    if (event['kind'] == 23194) {
      _handleNwcRequest(event);
    }

    // Handle deletion requests (kind 5) by removing referenced events
    if (event['kind'] == 5) {
      _handleDeletionRequest(event);
    }

    // Broadcast to active subscriptions (excluding closed ones)
    _broadcastEvent(event, null);

    // Send OK response
    _sendOk(eventId, true, 'Event stored', webSocket);
  }

  /// Handles NWC requests by generating fake responses for testing
  void _handleNwcRequest(Map<String, dynamic> nwcRequest) {
    // Simulate realistic delay
    Timer(Duration(milliseconds: 200), () {
      try {
        _generateNwcResponse(nwcRequest);
      } catch (e) {
        // Handle error silently
      }
    });
  }

  void _generateNwcResponse(Map<String, dynamic> nwcRequest) {
    final requestId = nwcRequest['id'] as String;
    final clientPubkey = nwcRequest['pubkey'] as String;
    final walletPubkey = _getWalletPubkey(nwcRequest);

    if (walletPubkey == null) {
      return;
    }

    // For dummy purposes, we'll create a basic success response
    // In a real implementation, you'd decrypt the content and parse the method

    // Generate fake successful pay_invoice response
    final responseContent = {
      'result_type': 'pay_invoice',
      'result': {
        'preimage': 'fake_preimage_$requestId',
        'fees_paid': 100, // 100 millisats
      },
    };

    // Create NWC response event (kind 23195)
    final responseEvent = {
      'id': Utils.generateRandomHex64(),
      'pubkey': walletPubkey,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'kind': 23195,
      'tags': [
        ['p', clientPubkey],
        ['e', requestId],
      ],
      'content': jsonEncode(responseContent),
      'sig': 'fake_signature_${Utils.generateRandomHex64()}',
    };

    // Store the response
    storage.storeEvent(responseEvent);

    // Broadcast to active subscriptions
    _broadcastEvent(responseEvent, null);
  }

  String? _getWalletPubkey(Map<String, dynamic> nwcRequest) {
    final tags = nwcRequest['tags'] as List?;
    if (tags == null) return null;

    for (final tag in tags) {
      if (tag is List && tag.length >= 2 && tag[0] == 'p') {
        return tag[1] as String;
      }
    }
    return null;
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

  void _broadcastEvent(Map<String, dynamic> event, WebSocket? excludeSocket) {
    final activeKeys = List<String>.from(_activeSubs.keys);
    for (final subId in activeKeys) {
      final sub = _activeSubs[subId];
      if (sub == null) continue;
      final closedVersion = _closedVersions[subId] ?? -1;
      if (sub.version <= closedVersion) continue;
      if (sub.webSocket != excludeSocket &&
          sub.webSocket.readyState == WebSocket.open &&
          sub.filters.any((f) => storage._matchesFilter(event, f))) {
        _sendEvent(subId, event, sub.webSocket);
      }
    }
  }

  void _sendMatchingEvents(
    String subId,
    List<RequestFilter> filters,
    WebSocket webSocket,
    int version,
  ) {
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
    String subId,
    Map<String, dynamic> event,
    WebSocket webSocket,
  ) {
    final message = jsonEncode(['EVENT', subId, event]);
    webSocket.add(message);
  }

  void _sendEose(String subId, WebSocket webSocket) {
    final message = jsonEncode(['EOSE', subId]);
    webSocket.add(message);
  }

  void _sendOk(
    String eventId,
    bool accepted,
    String message,
    WebSocket webSocket,
  ) {
    final response = jsonEncode(['OK', eventId, accepted, message]);
    webSocket.add(response);
  }

  void _sendError(String error, WebSocket webSocket) {
    try {
      final response = jsonEncode(['ERROR', error]);
      webSocket.add(response);
    } catch (e) {
      // Handle error silently
    }
  }

  void _sendClosed(String subId, String message, WebSocket webSocket) {
    final response = jsonEncode(['CLOSED', subId, message]);
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
            .map(
              (e) =>
                  e is List ? e.map((v) => v.toString()).toList() : <String>[],
            )
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
        event['content'] as String,
      ];

      // Serialize and hash
      final serialized = jsonEncode(eventData);
      final bytes = utf8.encode(serialized);
      final hash = sha256.convert(bytes);
      final computedId = hash.toString();
      final providedId = event['id'] as String;

      // Compare with provided ID
      return computedId == providedId;
    } catch (e) {
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

  /// Handles deletion requests (NIP-09) by removing referenced events
  void _handleDeletionRequest(Map<String, dynamic> deletionEvent) {
    final tags = deletionEvent['tags'] as List<dynamic>? ?? [];
    final authorPubkey = deletionEvent['pubkey'] as String;

    // Process 'e' tags (event deletions)
    for (final tag in tags) {
      if (tag is List && tag.isNotEmpty && tag[0] == 'e') {
        final eventIdToDelete = tag[1] as String?;
        if (eventIdToDelete != null) {
          // Only allow deletion of events authored by the same user
          final eventToDelete = storage._getEventById(eventIdToDelete);
          if (eventToDelete != null &&
              eventToDelete['pubkey'] == authorPubkey) {
            storage._deleteEventById(eventIdToDelete);
          }
        }
      }
    }

    // Process 'p' tags (profile deletions) - delete all events by these authors
    // but only if the deletion request is from the same pubkey
    for (final tag in tags) {
      if (tag is List && tag.isNotEmpty && tag[0] == 'p') {
        final pubkeyToDelete = tag[1] as String?;
        if (pubkeyToDelete != null && pubkeyToDelete == authorPubkey) {
          // Only allow users to delete their own profile/events
          storage._deleteEventsByAuthor(pubkeyToDelete);
        }
      }
    }
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

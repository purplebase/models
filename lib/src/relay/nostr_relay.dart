// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of models;

/// State for a single relay subscription
class RelaySubscriptionState with EquatableMixin {
  final String subscriptionId;
  final List<Map<String, dynamic>> events;
  final bool isEose; // End of stored events received
  final bool isClosed;
  final String? errorMessage;

  const RelaySubscriptionState({
    required this.subscriptionId,
    required this.events,
    this.isEose = false,
    this.isClosed = false,
    this.errorMessage,
  });

  RelaySubscriptionState copyWith({
    List<Map<String, dynamic>>? events,
    bool? isEose,
    bool? isClosed,
    String? errorMessage,
  }) {
    return RelaySubscriptionState(
      subscriptionId: subscriptionId,
      events: events ?? this.events,
      isEose: isEose ?? this.isEose,
      isClosed: isClosed ?? this.isClosed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    subscriptionId,
    events,
    isEose,
    isClosed,
    errorMessage,
  ];
}

/// StateNotifier for managing a single relay subscription
class RelaySubscriptionNotifier extends StateNotifier<RelaySubscriptionState> {
  final Request request;
  final NostrRelay relay;
  late final String subscriptionId;

  RelaySubscriptionNotifier({required this.request, required this.relay})
    : super(
        RelaySubscriptionState(
          subscriptionId: request.subscriptionId,
          events: [],
        ),
      ) {
    subscriptionId = request.subscriptionId;
    _initialize();
  }

  void _initialize() {
    // Register this subscription with the relay
    relay._registerSubscription(subscriptionId, this);

    // Send initial REQ message (this would normally go over WebSocket)
    relay._handleReq(subscriptionId, request.filters);
  }

  /// Called by relay when new events match this subscription
  void onEvent(Map<String, dynamic> event) {
    if (!mounted || state.isClosed) return;

    final eventKind = event['kind'] as int;
    final eventPubkey = event['pubkey'] as String;

    List<Map<String, dynamic>> updatedEvents = [...state.events];

    // Handle replaceable events - remove old ones with same addressable ID
    if (Utils.isEventReplaceable(eventKind)) {
      final newAddressableId = eventKind >= 30000 && eventKind < 40000
          ? _getAddressableId(event) // Parameterizable replaceable
          : '$eventKind:$eventPubkey:'; // Regular replaceable

      if (newAddressableId != null) {
        // Remove any existing events with the same addressable ID
        updatedEvents.removeWhere((existingEvent) {
          final existingKind = existingEvent['kind'] as int;
          final existingPubkey = existingEvent['pubkey'] as String;

          if (!Utils.isEventReplaceable(existingKind)) return false;

          final existingAddressableId =
              existingKind >= 30000 && existingKind < 40000
              ? _getAddressableId(existingEvent)
              : '$existingKind:$existingPubkey:';

          return existingAddressableId == newAddressableId;
        });
      }
    }

    // Add the new event
    updatedEvents.add(event);

    state = state.copyWith(events: updatedEvents);
  }

  /// Helper method to get addressable ID for parameterizable replaceable events
  String? _getAddressableId(Map<String, dynamic> event) {
    final kind = event['kind'] as int;
    final pubkey = event['pubkey'] as String;

    if (kind >= 30000 && kind < 40000) {
      // Parameterizable replaceable event - look for 'd' tag
      final tags = event['tags'] as List?;
      if (tags != null) {
        for (final tag in tags) {
          if (tag is List && tag.isNotEmpty && tag[0] == 'd') {
            final dValue = tag.length > 1 ? tag[1] as String : '';
            return '$kind:$pubkey:$dValue';
          }
        }
      }
      return '$kind:$pubkey:'; // No 'd' tag found
    }

    return null;
  }

  /// Called by relay when EOSE is reached
  void onEose() {
    if (!mounted || state.isClosed) return;
    state = state.copyWith(isEose: true);
  }

  /// Called by relay when subscription is closed
  void onClosed(String? message) {
    if (!mounted) return;
    state = state.copyWith(isClosed: true, errorMessage: message);
  }

  @override
  void dispose() {
    // Unregister from relay
    relay._unregisterSubscription(subscriptionId);
    super.dispose();
  }
}

/// A simple Nostr relay implementation following NIP-01 protocol
class NostrRelay {
  final int port;
  final String host;
  final Ref ref;
  final RelayInfoData relayInfo = RelayInfoData(
    name: 'dart-relay',
    description: 'A simple, in-memory Nostr relay written in Dart',
    supportedNips: [1, 2, 9, 10, 11, 42, 50], // Basic NIPs we support
    software: 'dart-relay',
    version: '1.0.0',
    contact: 'admin@example.com',
  );
  final MemoryStorage storage;
  late final MessageHandler messageHandler;

  HttpServer? _server;
  final Set<WebSocket> _connections = {};
  final Completer<void> _readyCompleter = Completer<void>();

  // Track active subscriptions: subId -> notifier
  final Map<String, RelaySubscriptionNotifier> _subscriptions = {};

  /// Returns a Future that completes when the relay is ready to accept connections
  Future<void> get ready => _readyCompleter.future;

  NostrRelay({required this.port, required this.host, required this.ref})
    : storage = MemoryStorage() {
    messageHandler = MessageHandler(storage);
  }

  /// Public API: Create a subscription (returns StateNotifier)
  RelaySubscriptionNotifier subscribe(Request request) {
    final notifier = RelaySubscriptionNotifier(request: request, relay: this);
    return notifier;
  }

  /// Public API: Publish events to the relay
  List<String> publish(List<Map<String, dynamic>> events) {
    final results = <String>[];

    for (final event in events) {
      try {
        // Validate event format
        if (!_validateEvent(event)) {
          throw Exception('Invalid event format');
        }

        // Validate event ID
        if (!_validateEventId(event)) {
          throw Exception('Invalid event ID');
        }

        // Store in memory
        final stored = storage.storeEvent(event);
        if (!stored) {
          throw Exception('Event rejected by storage');
        }

        // Handle NWC requests
        if (event['kind'] == 23194) {
          _handleNwcRequest(event);
        }

        // Broadcast to active subscriptions
        _broadcastEvent(event);

        results.add('OK: ${event['id']}');
      } catch (e) {
        results.add('ERROR: ${event['id']} - $e');
      }
    }

    return results;
  }

  /// Public API: Delete events by their IDs
  void deleteEvents([Set<String>? eventIds]) {
    if (eventIds == null) {
      storage.clear();
      // Invalidate all subscription caches after clearing all events
      _invalidateAllSubscriptionCaches();
      return;
    }

    for (final eventId in eventIds) {
      storage.removeEvent(eventId);
    }

    // Invalidate subscription caches after deleting specific events
    _invalidateAllSubscriptionCaches();
  }

  /// Invalidate cached results for all active subscriptions
  void _invalidateAllSubscriptionCaches() {
    // Create a copy to avoid concurrent modification
    final subscriptionsCopy = Map<String, RelaySubscriptionNotifier>.from(
      _subscriptions,
    );

    for (final entry in subscriptionsCopy.entries) {
      final subId = entry.key;
      final notifier = entry.value;

      if (notifier.state.isClosed) continue;

      // Re-query and send fresh results to the subscription
      _handleReq(subId, notifier.request.filters);
    }
  }

  /// Register a subscription notifier
  void _registerSubscription(String subId, RelaySubscriptionNotifier notifier) {
    _subscriptions[subId] = notifier;
  }

  /// Unregister a subscription notifier
  void _unregisterSubscription(String subId) {
    _subscriptions.remove(subId);
  }

  /// Handle REQ message (internal relay logic)
  void _handleReq(String subId, List<RequestFilter> filters) {
    final notifier = _subscriptions[subId];
    if (notifier == null) return;

    // Convert to storage filters
    final storageFilters = filters
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
        .toList();

    // Query existing events
    final events = storage.queryEvents(storageFilters);

    // Send events to notifier
    for (final event in events) {
      notifier.onEvent(event);
    }

    // Send EOSE
    notifier.onEose();
  }

  /// Broadcast new event to matching subscriptions
  void _broadcastEvent(Map<String, dynamic> event) {
    // Create a copy to avoid concurrent modification
    final subscriptionsCopy = Map<String, RelaySubscriptionNotifier>.from(
      _subscriptions,
    );

    print(
      '🔄 Relay: Broadcasting event ${event['id']} to ${subscriptionsCopy.length} subscriptions',
    );

    for (final entry in subscriptionsCopy.entries) {
      final subId = entry.key;
      final notifier = entry.value;

      if (notifier.state.isClosed) continue;

      // Check if event matches any filter in this subscription
      final matches = notifier.request.filters.any(
        (filter) => storage._matchesFilter(
          event,
          RequestFilter(
            ids: filter.ids,
            authors: filter.authors,
            kinds: filter.kinds,
            tags: filter.tags,
            since: filter.since,
            until: filter.until,
            limit: filter.limit,
            search: filter.search,
          ),
        ),
      );

      if (matches) {
        print(
          '🎯 Relay: Event ${event['id']} matches subscription $subId - sending to notifier',
        );
        notifier.onEvent(event);
      } else {
        print(
          '❌ Relay: Event ${event['id']} does not match subscription $subId filters',
        );
      }
    }
  }

  /// Handles NWC requests by generating fake responses for testing
  void _handleNwcRequest(Map<String, dynamic> nwcRequest) {
    print('🎭 Dummy NWC: Handling NWC request ${nwcRequest['id']}');

    // Simulate realistic delay
    Timer(Duration(milliseconds: 200), () {
      try {
        _generateNwcResponse(nwcRequest);
      } catch (e) {
        print('🎭 Dummy NWC: Error generating response: $e');
      }
    });
  }

  void _generateNwcResponse(Map<String, dynamic> nwcRequest) async {
    final requestId = nwcRequest['id'] as String;
    final clientPubkey = nwcRequest['pubkey'] as String;
    final walletPubkey = _getWalletPubkey(nwcRequest);

    if (walletPubkey == null) {
      print('🎭 Dummy NWC: No wallet pubkey found in request');
      return;
    }

    print(
      '🎭 Dummy NWC: Generating response from wallet $walletPubkey to client $clientPubkey',
    );

    // For dummy purposes, we'll use a more reliable heuristic based on content patterns
    // In a real implementation, you'd decrypt the content to get the actual method
    final content = nwcRequest['content'] as String;
    Map<String, dynamic> responseContent;

    // Better heuristic: look for method patterns in the encrypted content
    // Different methods have different typical encrypted patterns
    if (content.contains('balance') || content.length < 100) {
      // Likely get_balance (short content, often contains "balance")
      responseContent = {
        'result_type': 'get_balance',
        'error': null,
        'result': {
          'balance': 50000, // 50000 millisats fake balance
        },
      };
      print('🎭 Dummy NWC: Creating get_balance response');
    } else if (content.contains('invoice') && content.contains('amount')) {
      // Likely make_invoice (contains both "invoice" and "amount")
      responseContent = {
        'result_type': 'make_invoice',
        'error': null,
        'result': {
          'type': 'incoming',
          'invoice': 'lnbc50000n1pjqwdqcpp5...',
          'payment_hash': 'fake_payment_hash_$requestId',
          'amount': 5000, // 5000 millisats fake invoice amount
        },
      };
      print('🎭 Dummy NWC: Creating make_invoice response');
    } else {
      // Default to pay_invoice (contains "invoice" but not "amount", or other patterns)
      responseContent = {
        'result_type': 'pay_invoice',
        'error': null,
        'result': {
          'preimage': 'fake_preimage_$requestId',
          'fees_paid': 100, // 100 millisats
        },
      };
      print('🎭 Dummy NWC: Creating pay_invoice response');
    }

    print('🎭 Dummy NWC: Using expected wallet pubkey from request');
    print('🎭 Dummy NWC: Wallet pubkey: $walletPubkey');

    // Convert response content to JSON string
    final plainContent = jsonEncode(responseContent);

    // For dummy testing, create a fake encrypted response
    // In a real implementation, you'd use proper NIP-04 encryption
    final fakeEncryptedContent =
        'dummy_encrypted_${plainContent.length}_$requestId';

    print('🎭 Dummy NWC: Created fake encrypted content for testing');

    // Create NWC response event manually (kind 23195)
    // Use the expected wallet pubkey from the request
    final responseEventMap = {
      'pubkey': walletPubkey, // Use the expected wallet pubkey from request
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'kind': 23195,
      'tags': [
        ['p', clientPubkey],
        ['e', requestId],
      ],
      'content': fakeEncryptedContent,
    };

    // Calculate proper event ID using NIP-01 specification (same as _validateEventId)
    final safeTags = responseEventMap['tags'] as List;
    final eventData = [
      0, // event type
      responseEventMap['pubkey'] as String,
      responseEventMap['created_at'] as int,
      responseEventMap['kind'] as int,
      safeTags,
      responseEventMap['content'] as String,
    ];
    final serialized = jsonEncode(eventData);
    final bytes = utf8.encode(serialized);
    final hash = sha256.convert(bytes);
    final eventId = hash.toString();
    responseEventMap['id'] = eventId;

    // For dummy testing, use a simple signature (real implementation would use proper Schnorr signature)
    responseEventMap['sig'] = Utils.generateRandomHex64();

    print('🎭 Dummy NWC: Created event with proper ID: $eventId');

    print('🎭 Dummy NWC: Storing response event ${responseEventMap['id']}');

    // Store the response
    storage.storeEvent(responseEventMap);

    // Broadcast to matching subscriptions
    _broadcastEvent(responseEventMap);
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

  /// Starts the relay server
  Future<void> start() async {
    _server = await HttpServer.bind(host, port);

    _server!.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final webSocket = await WebSocketTransformer.upgrade(request);
        _handleWebSocket(webSocket);
      } else {
        // Handle HTTP requests (e.g., relay info)
        _handleHttpRequest(request);
      }
    });

    // Mark as ready after server is bound and listening
    _readyCompleter.complete();

    // Wait for ready to complete before returning
    await _readyCompleter.future;
  }

  /// Stops the relay server
  Future<void> stop() async {
    for (final connection in _connections) {
      await connection.close();
    }
    _connections.clear();

    // Close all subscriptions
    for (final notifier in _subscriptions.values) {
      notifier.onClosed('Server shutting down');
    }
    _subscriptions.clear();

    await _server?.close();
    messageHandler.dispose();
  }

  /// Handles WebSocket connections
  void _handleWebSocket(WebSocket webSocket) {
    _connections.add(webSocket);

    webSocket.listen(
      (message) {
        if (message is String) {
          messageHandler.handleMessage(message, webSocket);
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
      onDone: () {
        _connections.remove(webSocket);
      },
    );
  }

  /// Handles HTTP requests (for relay info)
  void _handleHttpRequest(HttpRequest request) {
    if (request.uri.path == '/' || request.uri.path == '/info') {
      request.response
        ..headers.contentType = ContentType.json
        ..write(relayInfo.toJson())
        ..close();
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found')
        ..close();
    }
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
}

// Riverpod provider for the relay instance
final relayProvider = Provider<NostrRelay>((ref) {
  return NostrRelay(port: 7777, host: 'localhost', ref: ref);
});

// Provider for relay subscriptions - this is what DummyStorageNotifier will use
final relaySubscriptionProvider =
    StateNotifierProvider.family<
      RelaySubscriptionNotifier,
      RelaySubscriptionState,
      Request
    >((ref, request) {
      final relay = ref.read(relayProvider);
      return relay.subscribe(request);
    });

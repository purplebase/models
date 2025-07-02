part of models;

/// A simple Nostr relay implementation
class NostrRelay {
  final int port;
  final String host;
  final RelayInfoData relayInfo;
  final MemoryStorage storage;
  final MessageHandler messageHandler;

  HttpServer? _server;
  final Set<WebSocket> _connections = {};

  NostrRelay({
    required this.port,
    required this.host,
    required this.relayInfo,
  })  : storage = MemoryStorage(),
        messageHandler = MessageHandler(MemoryStorage());

  /// Starts the relay server
  Future<void> start() async {
    _server = await HttpServer.bind(host, port);

    print('Nostr relay listening on ws://$host:$port');
    print('Relay info available at http://$host:$port');
    print('Supported NIPs: ${relayInfo.supportedNips}');

    _server!.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final webSocket = await WebSocketTransformer.upgrade(request);
        _handleWebSocket(webSocket);
      } else {
        // Handle HTTP requests (e.g., relay info)
        _handleHttpRequest(request);
      }
    });
  }

  /// Stops the relay server
  Future<void> stop() async {
    for (final connection in _connections) {
      await connection.close();
    }
    _connections.clear();

    await _server?.close();
    messageHandler.dispose();
  }

  /// Handles WebSocket connections
  void _handleWebSocket(WebSocket webSocket) {
    _connections.add(webSocket);

    webSocket.listen(
      (message) {
        if (message is String) {
          messageHandler.handleMessage(message);
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
      onDone: () {
        _connections.remove(webSocket);
      },
    );

    // Listen for outgoing messages from the message handler
    messageHandler.outgoingMessages.listen((message) {
      if (webSocket.readyState == WebSocket.open) {
        webSocket.add(jsonEncode(message));
      }
    });
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
}

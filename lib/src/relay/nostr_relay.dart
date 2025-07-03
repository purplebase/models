part of models;

/// A simple Nostr relay implementation
class NostrRelay {
  final int port;
  final String host;
  final RelayInfoData relayInfo = RelayInfoData(
    name: 'dart-relay',
    description: 'A simple, in-memory Nostr relay written in Dart',
    supportedNips: [1, 2, 9, 10, 11, 42, 50], // Basic NIPs we support
    software: 'dart-relay',
    version: '1.0.0',
    contact: 'admin@example.com',
  );
  final MemoryStorage storage;
  final MessageHandler messageHandler;

  HttpServer? _server;
  final Set<WebSocket> _connections = {};
  final Completer<void> _readyCompleter = Completer<void>();

  /// Returns a Future that completes when the relay is ready to accept connections
  Future<void> get ready => _readyCompleter.future;

  NostrRelay({
    required this.port,
    required this.host,
  })  : storage = MemoryStorage(),
        messageHandler = MessageHandler(MemoryStorage());

  /// Starts the relay server
  Future<void> start() async {
    _server = await HttpServer.bind(host, port);

    print('Nostr relay listening on ws://$host:$port');

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
}

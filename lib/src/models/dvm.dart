part of models;

/// Mixin for DVM request models that provides the standard run() pattern.
///
/// DVM (Data Vending Machine) requests follow NIP-90 conventions:
/// - Response kind = request kind + 1000
/// - Error kind = 7000
/// - Responses reference the request via `#e` tag
///
/// Usage:
/// ```dart
/// class MyDVMRequest extends RegularModel<MyDVMRequest>
///     with DVMRequest<MyDVMRequest> {
///   MyDVMRequest.fromMap(super.map, super.ref) : super.fromMap();
///
///   @override
///   int get responseKind => 6XXX; // request kind + 1000
/// }
/// ```
mixin DVMRequest<E extends Model<E>> on RegularModel<E> {
  /// The response kind for this DVM request.
  ///
  /// Per NIP-90, this is typically the request kind + 1000.
  int get responseKind;

  /// Execute DVM request and wait for response.
  ///
  /// [relays] - The relay target (URL or identifier) to publish the request to
  /// [timeout] - Maximum time to wait for DVM response (default: 16 seconds)
  ///
  /// Returns the first DVM response (success or error), or null on timeout.
  Future<Model<dynamic>?> run(
    String relays, {
    Duration timeout = const Duration(seconds: 16),
  }) async {
    final source = RemoteSource(relays: relays, stream: true);

    final provider = queryKinds(
      kinds: {responseKind, 7000}, // response kind + error kind
      tags: {
        '#e': {event.id},
      },
      limit: 1,
      source: source,
    );

    final completer = Completer<Model<dynamic>>();
    ProviderSubscription<StorageState>? subscription;

    try {
      // Listen to the query provider for streaming results
      subscription = ref.listen(provider, (_, state) {
        if (completer.isCompleted) return;

        if (state case StorageData(:final models) when models.isNotEmpty) {
          completer.complete(models.first);
        }
      });

      // Publish the request (do not save locally)
      await storage.publish({this}, source: source);

      // Wait for the response with timeout
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      return null;
    } finally {
      // Clean up the subscription (also cancels the relay subscription)
      subscription?.close();
    }
  }
}

/// Mixin for partial DVM request models with param tag helpers.
///
/// Provides convenient methods for adding NIP-90 param tags to DVM requests.
///
/// Usage:
/// ```dart
/// class PartialMyDVMRequest extends RegularPartialModel<MyDVMRequest>
///     with DVMPartialRequest<MyDVMRequest> {
///   PartialMyDVMRequest({required String input}) {
///     addParam('input', input);
///   }
/// }
/// ```
mixin DVMPartialRequest<E extends Model<E>> on RegularPartialModel<E> {
  /// Add a single param tag with key and value.
  ///
  /// Creates a tag in the format: `["param", key, value]`
  void addParam(String key, String value) {
    event.addTag('param', [key, value]);
  }

  /// Add multiple param tags from a map.
  void addParams(Map<String, String> params) {
    for (final entry in params.entries) {
      addParam(entry.key, entry.value);
    }
  }

  /// Add an optional param (only if value is non-null).
  void addOptionalParam(String key, String? value) {
    if (value != null) addParam(key, value);
  }

  /// Add an optional int param (only if value is non-null).
  void addOptionalIntParam(String key, int? value) {
    if (value != null) addParam(key, value.toString());
  }
}

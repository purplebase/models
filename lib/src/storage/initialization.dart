part of models;

/// Initialization provider that MUST be called from any client
/// application, with a [StorageConfiguration]
final initializationProvider =
    FutureProvider.family<void, StorageConfiguration>((ref, config) async {
      _dummySigner = DummySigner(ref);
      await ref.read(storageNotifierProvider.notifier).initialize(config);
    });

class StorageConfiguration extends Equatable {
  /// Path to the database (write to memory if absent)
  final String? databasePath;

  /// Whether to keep signatures in local storage (default `false`)
  final bool keepSignatures;

  /// Whether to BIP-340 verify the events received from relays (default `false`)
  final bool skipVerification;

  /// Default relay URLs keyed by label.
  ///
  /// These are used as fallbacks when no signed [RelayList] exists for a label.
  /// Once a user's signed RelayList is available, it takes precedence over defaults.
  ///
  /// Example:
  /// ```dart
  /// defaultRelays: {
  ///   'default': {'wss://relay.damus.io', 'wss://nos.lol'},
  ///   'AppCatalog': {'wss://relay.zapstore.dev'},
  /// }
  /// ```
  final Map<String, Set<String>> defaultRelays;

  /// The default source for query when absent from query()
  final Source defaultQuerySource;

  /// After this inactivity duration, relays disconnect (default: 5 minutes)
  final Duration idleTimeout;

  /// Duration to wait for relays to respond (final timeout)
  final Duration responseTimeout;

  /// Duration to wait for first EOSE before flushing (if at least 1 relay EOSE'd)
  final Duration eoseFirstFlushTimeout;

  /// How often event updates are emitted from [StorageNotifier] (default: 2 seconds)
  final Duration streamingBufferWindow;

  /// Maximum amount of recent models to keep in the database,
  /// older will be removed (default: 20000)
  final int keepMaxModels;

  /// Storage configuration
  StorageConfiguration({
    this.databasePath,
    this.keepSignatures = false,
    this.skipVerification = false,
    Map<String, Set<String>> defaultRelays = const {},
    this.defaultQuerySource = const LocalAndRemoteSource(stream: false),
    this.idleTimeout = const Duration(minutes: 5),
    this.responseTimeout = const Duration(seconds: 15),
    this.eoseFirstFlushTimeout = const Duration(seconds: 4),
    this.streamingBufferWindow = const Duration(seconds: 2),
    this.keepMaxModels = 20000,
  }) : defaultRelays = _normalizeRelays(defaultRelays);

  /// Normalize relay URLs in all relay sets
  static Map<String, Set<String>> _normalizeRelays(
    Map<String, Set<String>> relays,
  ) {
    final normalized = <String, Set<String>>{};

    for (final entry in relays.entries) {
      final normalizedUrls = <String>{};

      for (final url in entry.value) {
        final normalizedUrl = _normalizeRelayUrl(url);
        if (normalizedUrl != null) {
          normalizedUrls.add(normalizedUrl);
        }
      }

      if (normalizedUrls.isNotEmpty) {
        normalized[entry.key] = normalizedUrls;
      }
    }

    return normalized;
  }

  /// Normalize and sanitize a single relay URL
  static String? _normalizeRelayUrl(String url) {
    // Remove if contains comma
    if (url.contains(',')) return null;

    try {
      final uri = Uri.parse(url.trim());

      // Default to wss if not ws or wss
      final scheme = (uri.scheme == 'ws' || uri.scheme == 'wss')
          ? uri.scheme
          : 'wss';

      // Keep consistent trailing slash logic - remove if present
      final path = uri.path == '/' ? '' : uri.path;

      return Uri(
        scheme: scheme,
        host: uri.host,
        port: uri.port,
        path: path,
        query: uri.query.isEmpty ? null : uri.query,
        fragment: uri.fragment.isEmpty ? null : uri.fragment,
      ).toString();
    } catch (e) {
      // Could not parse URI, remove from list
      return null;
    }
  }

  /// Resolve relay URLs from a [RemoteSource].
  ///
  /// Resolution order:
  /// 1. If `source.relays` is null → empty set (TODO: implement outbox lookup)
  /// 2. If `source.relays` starts with `ws://` or `wss://` → ad-hoc relay URL
  /// 3. Otherwise → look up by label in defaults
  ///
  /// Note: Signed [RelayList] lookup happens in the storage layer, not here.
  /// This method only provides the default fallback.
  Set<String> getRelays({RemoteSource source = const RemoteSource()}) {
    if (source.relays == null) {
      // TODO: Implement outbox lookup (NIP-65)
      return {};
    }

    final relays = source.relays!;

    // Ad-hoc relay URL
    if (relays.startsWith('ws://') || relays.startsWith('wss://')) {
      final normalized = _normalizeRelayUrl(relays);
      return normalized != null ? {normalized} : {};
    }

    // Look up by identifier in defaults
    return defaultRelays[relays] ?? {};
  }

  @override
  List<Object?> get props => [
    databasePath,
    keepSignatures,
    skipVerification,
    defaultRelays,
    idleTimeout,
    responseTimeout,
    eoseFirstFlushTimeout,
    streamingBufferWindow,
    keepMaxModels,
  ];
}

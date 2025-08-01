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

  /// Define named collection of relays,
  /// Example: `{popular: {'wss://relay.damus.io', 'wss://relay.primal.net'}}`
  final Map<String, Set<String>> relayGroups;

  /// The default source for query when absent from query()
  final Source defaultQuerySource;

  /// The default group to use when unspecified
  final String defaultRelayGroup;

  /// After this inactivity duration, relays disconnect (default: 5 minutes)
  final Duration idleTimeout;

  /// Duration to wait for relays to respond
  final Duration responseTimeout;

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
    Map<String, Set<String>> relayGroups = const {},
    this.defaultQuerySource = const LocalAndRemoteSource(stream: false),
    this.defaultRelayGroup = 'default',
    this.idleTimeout = const Duration(minutes: 5),
    this.responseTimeout = const Duration(seconds: 6),
    this.streamingBufferWindow = const Duration(seconds: 2),
    this.keepMaxModels = 20000,
  }) : relayGroups = _normalizeRelayGroups(relayGroups);

  /// Normalize and sanitize relay URLs
  static Map<String, Set<String>> _normalizeRelayGroups(
    Map<String, Set<String>> groups,
  ) {
    final normalized = <String, Set<String>>{};

    for (final entry in groups.entries) {
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

  /// Find relays via relayUrls (takes priority) or resolve to a group's relayUrls
  Set<String> getRelays({RemoteSource source = const RemoteSource()}) {
    if (source.relayUrls.isNotEmpty) {
      return source.relayUrls;
    }
    final group = source.group ?? defaultRelayGroup;
    return relayGroups[group] ?? {};
  }

  @override
  List<Object?> get props => [
    databasePath,
    keepSignatures,
    skipVerification,
    relayGroups,
    defaultRelayGroup,
  ];
}

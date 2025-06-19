part of models;

/// Initialization provider that MUST be called from any client
/// application, with a [config]
final initializationProvider =
    FutureProvider.family<bool, StorageConfiguration>((ref, config) async {
  _dummySigner = DummySigner(ref);
  await ref.read(storageNotifierProvider.notifier).initialize(config);
  return true;
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

  /// The default group to use when unspecified
  final String? defaultRelayGroup;

  /// After this inactivity duration, relays disconnect (default: 5 minutes)
  final Duration idleTimeout;

  /// Duration to wait for relays to respond
  final Duration responseTimeout;

  /// How often event updates are emitted from [StorageNotifier] (default: 2 seconds)
  final Duration streamingBufferWindow;

  /// Maximum amount of recent models to keep in the database,
  /// older will be removed (default: 20000)
  final int keepMaxModels;

  StorageConfiguration({
    this.databasePath,
    this.keepSignatures = false,
    this.skipVerification = false,
    this.relayGroups = const {},
    this.defaultRelayGroup,
    this.idleTimeout = const Duration(minutes: 5),
    this.responseTimeout = const Duration(seconds: 6),
    this.streamingBufferWindow = const Duration(seconds: 2),
    this.keepMaxModels = 20000,
  }) {
    // TODO: Normalize/sanitize relayUrls, ensure no commas
  }

  /// Find relays given a group,
  /// [useDefault] if missing whether to return the default one
  Set<String> getRelays(
      {Source source = const RemoteSource(), bool useDefault = true}) {
    final k = source.group ?? (useDefault ? defaultRelayGroup : null);
    return relayGroups[k] ?? {};
  }

  @override
  List<Object?> get props => [
        databasePath,
        keepSignatures,
        skipVerification,
        relayGroups,
        defaultRelayGroup
      ];
}

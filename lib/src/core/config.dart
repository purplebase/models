part of models;

class StorageConfiguration extends Equatable {
  final String databasePath;
  final bool keepSignatures;
  final bool skipVerification;
  final Map<String, Set<String>> relayGroups;
  final String defaultRelayGroup;
  final Duration idleTimeout;
  final Duration streamingBufferWindow;

  const StorageConfiguration({
    required this.databasePath,
    this.keepSignatures = false,
    this.skipVerification = false,
    required this.relayGroups,
    required this.defaultRelayGroup,
    this.idleTimeout = const Duration(minutes: 5),
    this.streamingBufferWindow = const Duration(seconds: 2),
  });

  factory StorageConfiguration.empty() {
    return StorageConfiguration(
        databasePath: '', relayGroups: {}, defaultRelayGroup: '');
  }

  Set<String> getRelays({String? relayGroup, bool useDefault = true}) {
    final k = useDefault ? (relayGroup ?? defaultRelayGroup) : relayGroup;
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

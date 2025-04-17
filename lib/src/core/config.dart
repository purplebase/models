part of models;

class StorageConfiguration extends Equatable {
  final String databasePath;
  final bool keepSignatures;
  final bool skipVerification;
  final Map<String, Set<String>> relayGroups;
  final String? defaultRelayGroup;
  final Duration idleTimeout;
  final Duration streamingBufferWindow;

  const StorageConfiguration({
    this.databasePath = '',
    this.keepSignatures = false,
    this.skipVerification = false,
    this.relayGroups = const {},
    this.defaultRelayGroup,
    this.idleTimeout = const Duration(minutes: 5),
    this.streamingBufferWindow = const Duration(seconds: 2),
  });

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

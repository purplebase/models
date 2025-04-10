import 'package:equatable/equatable.dart';

final class StorageConfiguration extends Equatable {
  final String databasePath;
  final bool keepSignatures;
  final bool skipVerification;
  final Map<String, Set<String>> relayGroups;
  final String defaultRelayGroup;
  const StorageConfiguration({
    required this.databasePath,
    this.keepSignatures = false,
    this.skipVerification = false,
    required this.relayGroups,
    required this.defaultRelayGroup,
  });

  factory StorageConfiguration.empty() {
    return StorageConfiguration(
        databasePath: '', relayGroups: {}, defaultRelayGroup: '');
  }

  Set<String> getRelays([String? relayGroup]) {
    return relayGroups[relayGroup ?? defaultRelayGroup] ??
        relayGroups.values.firstOrNull ??
        {};
  }

  @override
  List<Object?> get props => [databasePath, keepSignatures];
}

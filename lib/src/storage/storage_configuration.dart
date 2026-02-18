import 'package:equatable/equatable.dart';

import '../source/source.dart';
import '../source/local_and_remote_source.dart';

/// Configuration for storage initialization.
class StorageConfiguration extends Equatable {
  /// Path to the database (write to memory if absent)
  final String? databasePath;

  /// Whether to keep signatures in local storage (default `false`)
  final bool keepSignatures;

  /// Whether to BIP-340 verify the events received from relays (default `false`)
  final bool skipVerification;

  /// Default relay URLs keyed by label.
  ///
  /// These are used as fallbacks when no signed RelayList exists for a label.
  /// Once a user's signed RelayList is available, it takes precedence over defaults.
  final Map<String, Set<String>> defaultRelays;

  /// The default source for query when absent from query()
  final Source defaultQuerySource;

  /// After this inactivity duration, relays disconnect
  final Duration idleTimeout;

  /// Notifier-level safety-net timeout for multi-relay queries.
  /// Must be > PoolConfiguration.eoseTimeout to avoid races.
  final Duration responseTimeout;

  /// How often event updates are emitted from StorageNotifier
  final Duration streamingBufferDuration;

  /// Maximum amount of recent models to keep in the database,
  /// older will be removed
  final int keepMaxModels;

  /// Duration to buffer remote requests before merging and sending.
  final Duration requestBufferDuration;

  /// Storage configuration
  StorageConfiguration({
    this.databasePath,
    this.keepSignatures = false,
    this.skipVerification = false,
    this.defaultRelays = const {},
    this.defaultQuerySource = const LocalAndRemoteSource(stream: false),
    this.idleTimeout = const Duration(minutes: 5),
    this.responseTimeout = const Duration(seconds: 4),
    this.streamingBufferDuration = const Duration(seconds: 2),
    this.keepMaxModels = 20000,
    this.requestBufferDuration = const Duration(milliseconds: 16),
  });

  @override
  List<Object?> get props => [
        databasePath,
        keepSignatures,
        skipVerification,
        defaultRelays,
        idleTimeout,
        responseTimeout,
        streamingBufferDuration,
        keepMaxModels,
        requestBufferDuration,
      ];
}

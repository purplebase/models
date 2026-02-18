import 'source.dart';

/// Source configuration for remote relay queries.
///
/// The [relays] parameter is a unified way to specify relay targets:
/// - If `null` → TODO: future outbox lookup (NIP-65)
/// - If starts with `ws://` or `wss://` → ad-hoc relay URL
/// - Otherwise → label to look up [RelayList] by kind
///
/// The [stream] parameter controls query behavior:
/// - `stream: true` (default) → Fire-and-forget, events arrive via callbacks
/// - `stream: false` → Blocking, waits for EOSE before returning
class RemoteSource extends Source {
  /// Relay target: URL (wss://...) or RelayList label.
  final dynamic relays;

  /// Whether to keep streaming updates after initial load.
  final bool stream;

  const RemoteSource({
    this.relays,
    this.stream = true,
  });

  RemoteSource copyWith({
    dynamic relays,
    bool? stream,
  }) {
    return RemoteSource(
      relays: relays ?? this.relays,
      stream: stream ?? this.stream,
    );
  }

  @override
  List<Object?> get props => [relays, stream];

  @override
  String toString() {
    return 'RemoteSource: ${relays ?? 'outbox'} [stream=$stream]';
  }
}

part of models;

sealed class Source extends Equatable {
  const Source();

  @override
  List<Object?> get props => [];
}

final class LocalSource extends Source {
  const LocalSource();
}

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
///
/// Example usage:
/// ```dart
/// // Ad-hoc relay URL (streaming)
/// RemoteSource(relays: 'wss://relay.example.com')
///
/// // One-shot blocking query
/// RemoteSource(relays: 'wss://relay.example.com', stream: false)
///
/// // Look up RelayList by label
/// RemoteSource(relays: 'AppCatalog')
///
/// // Default (will use outbox when implemented)
/// RemoteSource()
/// ```
final class RemoteSource extends Source {
  /// Relay target: URL (wss://...) or RelayList label.
  ///
  /// - `null` → outbox lookup (future)
  /// - URL | List → ad-hoc relay(s)
  /// - Otherwise → RelayList label lookup
  final dynamic relays;

  /// Whether to keep streaming updates after initial load.
  ///
  /// - `true` (default): Fire-and-forget, events arrive via callbacks
  /// - `false`: Blocking, waits for EOSE before returning
  final bool stream;

  const RemoteSource({this.relays, this.stream = true});

  RemoteSource copyWith({dynamic relays, bool? stream}) {
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

/// Source configuration that queries both local storage and remote relays.
final class LocalAndRemoteSource extends RemoteSource {
  /// Cache duration for author+kind queries on replaceable events.
  ///
  /// When set and the query is cacheable (author+kind only, replaceable kinds,
  /// no tags/ids/search/until), fresh local data will be returned without
  /// hitting remote relays if fetched within this duration.
  ///
  /// Note: When [cachedFor] is set, [stream] is forced to `false`.
  final Duration? cachedFor;

  const LocalAndRemoteSource({
    super.relays,
    super.stream = true,
    this.cachedFor,
  });

  /// When [cachedFor] is set, streaming is disabled.
  @override
  bool get stream => cachedFor != null ? false : super.stream;

  @override
  LocalAndRemoteSource copyWith({
    dynamic relays,
    bool? stream,
    Duration? cachedFor,
  }) {
    return LocalAndRemoteSource(
      relays: relays ?? this.relays,
      stream: stream ?? super.stream,
      cachedFor: cachedFor ?? this.cachedFor,
    );
  }

  @override
  List<Object?> get props => [relays, stream, cachedFor];

  @override
  String toString() {
    return 'LocalAnd${super.toString()}';
  }
}

// final class OutboxRelaySource extends RemoteSource {
//   const OutboxRelaySource({super.stream});
// }

// State

sealed class StorageState<E extends Model<dynamic>> with EquatableMixin {
  final List<E> models;
  const StorageState(this.models);

  @override
  List<Object?> get props => [models];

  @override
  String toString() {
    return '[$runtimeType] $models';
  }
}

final class StorageLoading<E extends Model<dynamic>> extends StorageState<E> {
  StorageLoading(super.models);
}

final class StorageData<E extends Model<dynamic>> extends StorageState<E> {
  StorageData(super.models);
}

@protected
final class InternalStorageData extends StorageState {
  final Set<String> updatedIds;
  final Request? req;
  const InternalStorageData({this.updatedIds = const {}, this.req})
    : super(const []);
}

final class StorageError<E extends Model<dynamic>> extends StorageState<E> {
  late final Exception exception;
  final StackTrace? stackTrace;
  StorageError(super.models, {required dynamic exception, this.stackTrace}) {
    this.exception = exception is Exception
        ? exception
        : Exception(exception.toString());
  }
}

final class PublishResponse {
  final Map<String, Set<RelayEventState>> results = {};
  Set<String> unreachableRelayUrls = {};

  void addEvent(
    String eventId, {
    required String relayUrl,
    bool accepted = true,
    String? message,
  }) {
    results[eventId] ??= {};
    results[eventId]!.add(
      RelayEventState(relayUrl, accepted: accepted, message: message),
    );
  }
}

final class RelayEventState {
  final String relayUrl;
  final bool accepted;
  final String? message;
  const RelayEventState(this.relayUrl, {this.accepted = true, this.message});
}

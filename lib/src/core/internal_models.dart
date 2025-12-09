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
/// Example usage:
/// ```dart
/// // Ad-hoc relay URL
/// RemoteSource(relays: 'wss://relay.example.com')
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
  /// - `null` → TODO: outbox lookup
  /// - URL → ad-hoc relay
  /// - Otherwise → RelayList label lookup
  final String? relays;

  /// Whether to keep streaming updates after initial load.
  final bool stream;

  /// Whether to run this query in the background.
  final bool background;

  const RemoteSource({
    this.relays,
    this.stream = true,
    this.background = false,
  });

  RemoteSource copyWith({
    String? relays,
    bool? stream,
    bool? background,
  }) {
    return RemoteSource(
      relays: relays ?? this.relays,
      stream: stream ?? this.stream,
      background: background ?? this.background,
    );
  }

  @override
  List<Object?> get props => [relays, stream, background];

  @override
  String toString() {
    return 'RemoteSource: ${relays ?? 'outbox'} [stream=$stream, background=$background]';
  }
}

/// Source configuration that queries both local storage and remote relays.
final class LocalAndRemoteSource extends RemoteSource {
  const LocalAndRemoteSource({
    super.relays,
    super.stream = true,
    super.background = false,
  });

  @override
  LocalAndRemoteSource copyWith({
    String? relays,
    bool? stream,
    bool? background,
  }) {
    return LocalAndRemoteSource(
      relays: relays ?? this.relays,
      stream: stream ?? this.stream,
      background: background ?? this.background,
    );
  }

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

part of models;

//***** PUBLIC API ******//

sealed class Source {
  final String? group;
  const Source({this.group});
}

final class LocalSource extends Source {
  const LocalSource({super.group});
}

final class RemoteSource extends Source {
  final bool stream;
  final bool includeLocal;
  const RemoteSource(
      {super.group, this.includeLocal = true, this.stream = true});
}

final class OutboxRelaySource extends RemoteSource {
  const OutboxRelaySource({super.stream});
}

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
  const InternalStorageData([this.updatedIds = const {}]) : super(const []);
}

final class StorageError<E extends Model<dynamic>> extends StorageState<E> {
  // TODO: Needs relay url (or link to Relay object)
  // TODO: Needs type (was failure querying or publishing)
  // TODO: Actual Relay class, backed by a table and with relationships to regular models?
  final Exception exception;
  final StackTrace? stackTrace;
  StorageError(super.models, {required this.exception, this.stackTrace});
}

final class PublishResponse {
  final Map<String, Set<RelayEventState>> results = {};
  // TODO: Implement
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

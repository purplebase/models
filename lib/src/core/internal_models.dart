part of models;

sealed class Source {
  const Source();
}

final class LocalSource extends Source {
  const LocalSource();
}

final class RemoteSource extends Source {
  final bool background;
  final String? group;
  final bool stream;
  const RemoteSource({this.group, this.stream = true, this.background = false});

  @override
  String toString() {
    return 'RemoteSource: $group [stream=$stream, background=$background]';
  }
}

final class LocalAndRemoteSource extends RemoteSource {
  const LocalAndRemoteSource(
      {super.group, super.stream = true, super.background = false});
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
    this.exception =
        exception is Exception ? exception : Exception(e.toString());
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

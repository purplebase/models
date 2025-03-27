import 'package:models/models.dart';

sealed class StorageState {
  final List<Event> models;
  const StorageState(this.models);
}

final class StorageLoading extends StorageState {
  StorageLoading(super.models);
}

final class StorageData extends StorageState {
  StorageData(super.models);
}

final class StorageError extends StorageState {
  final Exception exception;
  final StackTrace? stackTrace;
  StorageError(super.models, {required this.exception, this.stackTrace});
}

class StorageSignal {}

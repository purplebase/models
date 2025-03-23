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

// sealed class RelayState {
//   final String? subscriptionId;
//   final List<Event>? models;
//   const RelayState(this.models, {this.subscriptionId});
// }

// final class RelayIdle<T> extends RelayState {
//   RelayIdle() : super(null, subscriptionId: null);
// }

// final class RelayLoading extends RelayState {
//   RelayLoading(List<Event>? models, {required String subscriptionId})
//       : super(models, subscriptionId: subscriptionId);
// }

// final class RelayError extends RelayState {
//   final String message;
//   const RelayError(List<Event>? models,
//       {required this.message, required String subscriptionId})
//       : super(models, subscriptionId: subscriptionId);
// }

// final class RelayData extends RelayState {
//   // case of RelayData, models is never null
//   @override
//   List<Event> get models => super.models!;
//   final bool isStreaming;
//   const RelayData(List<Event> models,
//       {this.isStreaming = false, required String subscriptionId})
//       : super(models, subscriptionId: subscriptionId);
// }

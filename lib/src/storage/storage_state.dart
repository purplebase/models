import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../core/model.dart';
import '../filter/request.dart';

export '../core/publish_response.dart';

/// Sealed hierarchy representing the state of a storage query.
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

/// Loading state — query in progress.
final class StorageLoading<E extends Model<dynamic>> extends StorageState<E> {
  StorageLoading(super.models);
}

/// Data state — query completed successfully.
final class StorageData<E extends Model<dynamic>> extends StorageState<E> {
  StorageData(super.models);
}

/// Internal storage data — used for notifying about storage mutations.
/// Not exposed to consumers.
@protected
final class InternalStorageData extends StorageState {
  final Set<String> updatedIds;
  final Request? req;
  const InternalStorageData({this.updatedIds = const {}, this.req})
      : super(const []);
}

/// Error state — query failed. Preserves last-known models.
final class StorageError<E extends Model<dynamic>> extends StorageState<E> {
  late final Exception exception;
  final StackTrace? stackTrace;
  StorageError(super.models, {required dynamic exception, this.stackTrace}) {
    this.exception = exception is Exception
        ? exception
        : Exception(exception.toString());
  }
}

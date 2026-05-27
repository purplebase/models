import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../core/model.dart';
import '../filter/request.dart';

export '../core/publish_response.dart';

/// Sealed hierarchy representing the state of a storage query.
sealed class StorageState<E extends Model<dynamic>> with EquatableMixin {
  final List<E> models;
  final int revision;
  const StorageState(this.models, {this.revision = 0});

  @override
  List<Object?> get props => [models, revision];

  @override
  String toString() {
    return '[$runtimeType] $models';
  }
}

/// Loading state — query in progress.
final class StorageLoading<E extends Model<dynamic>> extends StorageState<E> {
  StorageLoading(super.models, {super.revision});
}

/// Data state — query completed successfully.
final class StorageData<E extends Model<dynamic>> extends StorageState<E> {
  StorageData(super.models, {super.revision});
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
  StorageError(
    super.models, {
    required dynamic exception,
    this.stackTrace,
    super.revision,
  }) {
    this.exception = exception is Exception
        ? exception
        : Exception(exception.toString());
  }
}

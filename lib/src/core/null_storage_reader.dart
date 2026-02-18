import 'model.dart';
import '../filter/request.dart';

/// A no-op StorageReader that returns empty results.
///
/// Used for creating models in tests that don't need relationship resolution.
class NullStorageReader implements StorageReader {
  static final instance = NullStorageReader._();

  const NullStorageReader._();
  const NullStorageReader();

  @override
  List<E> querySync<E extends Model<dynamic>>(Request<E> req) => [];

  @override
  int get cacheVersion => 0;
}

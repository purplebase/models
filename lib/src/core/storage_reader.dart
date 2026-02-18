import 'model.dart';
import '../filter/request.dart';

/// Minimal read interface for model relationship resolution.
/// Decouples models from Riverpod.
///
/// Models use this interface to synchronously query related data
/// (via BelongsTo/HasMany getters) without needing a Riverpod Ref.
abstract class StorageReader {
  /// Synchronous local query (used by BelongsTo/HasMany getters).
  List<E> querySync<E extends Model<dynamic>>(Request<E> req);

  /// Cache version — incremented on any storage mutation.
  /// Used by Relationship to invalidate cached query results.
  int get cacheVersion;
}

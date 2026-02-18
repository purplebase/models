import '../core/model.dart';
import '../filter/request.dart';
import '../source/source.dart';
import 'nested_query.dart';

/// Relationship to other models established via a [Request].
///
/// Uses [StorageReader] for synchronous relationship resolution,
/// decoupled from Riverpod.
sealed class Relationship<E extends Model<dynamic>> {
  final Request<E>? req;
  final StorageReader _reader;

  /// Cached query result to avoid repeated queries within same storage state.
  /// Only non-empty results are cached - empty results always re-query since
  /// related data may arrive later within the same cache version.
  List<E>? _cachedModels;
  int? _cachedAtVersion;

  Relationship(this._reader, this.req);

  bool get isLoading => false;

  List<E> get _models {
    if (req == null) return [];

    final currentVersion = _reader.cacheVersion;

    if (_cachedModels != null &&
        _cachedModels!.isNotEmpty &&
        _cachedAtVersion == currentVersion) {
      return _cachedModels!;
    }

    _cachedModels = _reader.querySync(req!);
    _cachedAtVersion = currentVersion;
    return _cachedModels!;
  }

  /// Create a nested query descriptor for this relationship.
  NestedQuery query({
    Source? source,
    String? subscriptionPrefix,
    Set<NestedQuery> Function(E)? and,
  }) {
    return NestedQuery(
      request: req,
      source: source,
      subscriptionPrefix: subscriptionPrefix,
      and: and == null ? null : (m) => and(m as E),
    );
  }
}

/// A relationship with one value
final class BelongsTo<E extends Model<dynamic>> extends Relationship<E> {
  BelongsTo(super.reader, super.req);

  E? get value {
    return _models.firstOrNull;
  }

  bool get isPresent => _models.isNotEmpty;
}

/// A relationship with multiple values
final class HasMany<E extends Model<dynamic>> extends Relationship<E> {
  HasMany(super.reader, super.req);

  List<E> toList() => _models;

  E? get firstOrNull => _models.firstOrNull;
  bool get isEmpty => _models.isEmpty;
  bool get isNotEmpty => _models.isNotEmpty;
  int get length => _models.length;
  Set<E> toSet() => _models.toSet();
}

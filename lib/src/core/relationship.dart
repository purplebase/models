part of models;

/// Descriptor for a nested query on a relationship.
///
/// Created via [Relationship.query] and returned from the `and` callback.
/// Contains the request to execute plus optional overrides for source and
/// subscription prefix. When these are null, values are inherited from the
/// outer query.
class NestedQuery with EquatableMixin {
  final Request? request;
  final Source? source;
  final String? subscriptionPrefix;
  final Set<NestedQuery> Function(Model<dynamic>)? and;

  const NestedQuery({
    required this.request,
    this.source,
    this.subscriptionPrefix,
    this.and,
  });

  /// Equality is based on request only - used to track streaming state.
  @override
  List<Object?> get props => [request];
}

/// Relationship to other models established via a [Request]
sealed class Relationship<E extends Model<dynamic>> {
  final Request<E>? req;
  final Ref ref;
  final StorageNotifier storage;

  /// Cached query result to avoid repeated SQLite queries within same storage state.
  List<E>? _cachedModels;
  int? _cachedAtVersion;

  Relationship(this.ref, this.req)
    : storage = ref.read(storageNotifierProvider.notifier);

  // TODO [cache]: if _cache[req] exists and is null
  // (it is created when the big rel query is fired to relays)
  bool get isLoading => false;

  List<E> get _models {
    if (req == null) return [];

    final currentVersion = storage.cacheVersion;
    if (_cachedModels != null && _cachedAtVersion == currentVersion) {
      return _cachedModels!;
    }

    _cachedModels = storage.querySync(req!);
    _cachedAtVersion = currentVersion;
    return _cachedModels!;
  }

  /// Create a nested query descriptor for this relationship.
  ///
  /// By default inherits source and subscriptionPrefix from the outer query.
  /// Override per-relationship as needed:
  ///
  /// ```dart
  /// query<App>(
  ///   authors: {pubkey},
  ///   source: LocalSource(),
  ///   and: (app) => {
  ///     app.latestRelease.query(
  ///       source: RemoteSource(stream: false),
  ///       and: (release) => {release.latestMetadata.query()},
  ///     ),
  ///     app.author.query(source: RemoteSource(relays: {'social'})),
  ///     app.appStacks.query(), // inherits outer source
  ///   },
  /// )
  /// ```
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
  BelongsTo(super.ref, super.req);

  E? get value {
    return _models.firstOrNull;
  }

  bool get isPresent => _models.isNotEmpty;

  Future<E?> get valueAsync async {
    if (req == null) return null;
    final updatedReq = req!.filters.first.copyWith(limit: 1).toRequest();
    final models = await storage.query<E>(updatedReq, source: LocalSource());
    return models.firstOrNull;
  }
}

/// A relationship with multiple values
final class HasMany<E extends Model<dynamic>> extends Relationship<E> {
  HasMany(super.ref, super.req);

  List<E> toList() => _models;

  Future<List<E>> toListAsync() async {
    if (req == null) return [];
    return await storage.query<E>(req!, source: LocalSource());
  }

  E? get firstOrNull => _models.firstOrNull;
  bool get isEmpty => _models.isEmpty;
  bool get isNotEmpty => _models.isNotEmpty;
  int get length => _models.length;
  Set<E> toSet() => _models.toSet();
}

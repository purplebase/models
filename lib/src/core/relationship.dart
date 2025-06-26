part of models;

/// Relationship to other models established via a [Request]
sealed class Relationship<E extends Model<dynamic>> {
  final Request<E>? req;
  final Ref ref;
  final StorageNotifier storage;

  Relationship(this.ref, this.req)
      : storage = ref.read(storageNotifierProvider.notifier);

  List<E> get _models =>
      storage._requestCache.values
          .firstWhereOrNull((map) => map.keys.contains(req))?[req]
          ?.cast<E>() ??
      <E>[];

  // TODO: Should have a mutable LoadingState, etc to be checked from the widget
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

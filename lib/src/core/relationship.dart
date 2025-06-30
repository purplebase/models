part of models;

/// Relationship to other models established via a [Request]
sealed class Relationship<E extends Model<dynamic>> {
  final Request<E>? req;
  final Ref ref;
  final StorageNotifier storage;

  Relationship(this.ref, this.req)
      : storage = ref.read(storageNotifierProvider.notifier);

  // TODO [cache]: if _cache[req] exists and is null
  // (it is created when the big rel query is fired to relays)
  bool get isLoading => false;
  List<E> get _models => req == null ? [] : storage.querySync(req!);
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

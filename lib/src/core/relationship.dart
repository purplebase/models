part of models;

// TODO: Make sure there is always access to keys (vs just models), goes in here or models themselves?
sealed class Relationship<E extends Model<dynamic>> {
  final RequestFilter<E>? req;
  final Ref ref;
  final StorageNotifier storage;
  Relationship(this.ref, this.req)
      : storage = ref.read(storageNotifierProvider.notifier);

  List<E> get _models {
    if (req == null) return [];
    final cachedModels = storage.requestCache.values
        .firstWhereOrNull((m) => m.containsKey(req))?[req];
    return (cachedModels ?? storage.querySync<E>(req!)).cast();
  }

  Future<List<E>> _modelsAsync({int? limit}) async {
    if (req == null) return [];
    final updatedReq = req!.copyWith(limit: limit, remote: false);
    final models =
        await ref.read(storageNotifierProvider.notifier).query<E>(updatedReq);
    return models;
  }
}

final class BelongsTo<E extends Model<dynamic>> extends Relationship<E> {
  BelongsTo(super.ref, super.req);

  E? get value {
    return _models.firstOrNull;
  }

  bool get isPresent => _models.isNotEmpty;

  Future<E?> get valueAsync async {
    final models = await _modelsAsync(limit: 1);
    return models.firstOrNull;
  }
}

// TODO: Support multiple reqs for multiple PRE addressable IDs
// TODO: Add req to further restrict the rel.req (e.g. to paginate)
final class HasMany<E extends Model<dynamic>> extends Relationship<E> {
  HasMany(super.ref, super.req);

  List<E> toList() => _models;

  Future<List<E>> toListAsync() => _modelsAsync();

  E? get firstOrNull => _models.firstOrNull;
  bool get isEmpty => _models.isEmpty;
  bool get isNotEmpty => _models.isNotEmpty;
  int get length => _models.length;
  Set<E> toSet() => _models.toSet();
}

part of models;

sealed class Relationship<E extends Event<dynamic>> {
  final RequestFilter<E>? req;
  final Ref ref;
  final StorageNotifier storage;
  Relationship(this.ref, this.req)
      : storage = ref.read(storageNotifierProvider.notifier);

  List<E> get _events {
    if (req == null) return [];
    final cachedEvents = storage.requestCache.values
        .firstWhereOrNull((m) => m.containsKey(req))?[req];
    return (cachedEvents ?? storage.querySync<E>(req!)).cast();
  }

  Future<List<E>> _eventsAsync({int? limit}) async {
    if (req == null) return [];
    final updatedReq = req!.copyWith(limit: limit, remote: false);
    final events =
        await ref.read(storageNotifierProvider.notifier).query<E>(updatedReq);
    return events;
  }
}

final class BelongsTo<E extends Event<dynamic>> extends Relationship<E> {
  BelongsTo(super.ref, super.req);

  E? get value {
    return _events.firstOrNull;
  }

  bool get isPresent => _events.isNotEmpty;

  Future<E?> get valueAsync async {
    final events = await _eventsAsync(limit: 1);
    return events.firstOrNull;
  }
}

// TODO: Support multiple reqs for multiple PRE addressable IDs
// TODO: Add req to further restrict the rel.req (e.g. to paginate)
final class HasMany<E extends Event<dynamic>> extends Relationship<E> {
  HasMany(super.ref, super.req);

  List<E> toList() => _events;

  Future<List<E>> toListAsync() => _eventsAsync();

  E? get firstOrNull => _events.firstOrNull;
  bool get isEmpty => _events.isEmpty;
  bool get isNotEmpty => _events.isNotEmpty;
  int get length => _events.length;
  Set<E> toSet() => _events.toSet();
}

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';

sealed class Relationship<E extends Event<E>> {
  final RequestFilter req;
  final Ref ref;
  Relationship(this.ref, this.req);

  Future<List<E>> toList({int? limit}) async {
    final updatedReq = req.copyWith(limit: limit, storageOnly: true);
    final events = await ref.read(storageProvider).query(updatedReq);
    return events.whereType<E>().toList();
  }
}

class BelongsTo<E extends Event<E>> extends Relationship<E> {
  BelongsTo(Ref ref, RequestFilter req) : super(ref, req.copyWith(limit: 1));
  Future<E?> get value async {
    final events = await toList();
    return events.firstOrNull;
  }
}

class HasMany<E extends Event<E>> extends Relationship<E> {
  HasMany(super.ref, super.req);
}

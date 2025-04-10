import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';

sealed class Relationship<E extends Event<dynamic>> {
  final RequestFilter? req;
  final Ref ref;
  Relationship(this.ref, this.req);

  Set<String> get ids => req?.ids ?? {};

  List<E> toList({int? limit}) {
    if (req == null) {
      return [];
    }
    final updatedReq = req!.copyWith(limit: limit, storageOnly: true);
    final events =
        ref.read(storageNotifierProvider.notifier).querySync(updatedReq);
    return events.whereType<E>().toList();
  }

  Future<List<E>> toListAsync({int? limit}) async {
    if (req == null) {
      return [];
    }
    final updatedReq = req!.copyWith(limit: limit, storageOnly: true);
    final events =
        await ref.read(storageNotifierProvider.notifier).query(updatedReq);
    return events.whereType<E>().toList();
  }
}

final class BelongsTo<E extends Event<dynamic>> extends Relationship<E> {
  BelongsTo(Ref ref, RequestFilter? req) : super(ref, req?.copyWith(limit: 1));
  E? get value {
    return toList().firstOrNull;
  }

  Future<E?> get valueAsync async {
    final events = await toListAsync();
    return events.firstOrNull;
  }
}

final class HasMany<E extends Event<dynamic>> extends Relationship<E> {
  HasMany(super.ref, super.req);
}

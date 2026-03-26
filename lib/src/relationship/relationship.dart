import 'package:riverpod/riverpod.dart';

import '../core/model.dart';
import '../filter/request.dart';
import '../source/source.dart';
import '../storage/storage_notifier.dart';
import 'nested_query.dart';

sealed class Relationship<E extends Model<dynamic>> {
  final Request<E>? req;
  final Ref ref;
  final StorageNotifier storage;

  List<E>? _cachedModels;
  int? _cachedAtVersion;

  Relationship(this.ref, this.req)
      : storage = ref.read(storageNotifierProvider.notifier);

  bool get isLoading => false;

  List<E> get _models {
    if (req == null) return [];

    final currentVersion = storage.cacheVersion;

    if (_cachedModels != null &&
        _cachedModels!.isNotEmpty &&
        _cachedAtVersion == currentVersion) {
      return _cachedModels!;
    }

    _cachedModels = storage.querySync(req!);
    _cachedAtVersion = currentVersion;
    return _cachedModels!;
  }

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

final class BelongsTo<E extends Model<dynamic>> extends Relationship<E> {
  BelongsTo(super.ref, super.req);

  E? get value => _models.firstOrNull;
  bool get isPresent => _models.isNotEmpty;
}

final class HasMany<E extends Model<dynamic>> extends Relationship<E> {
  HasMany(super.ref, super.req);

  List<E> toList() => _models;
  E? get firstOrNull => _models.firstOrNull;
  bool get isEmpty => _models.isEmpty;
  bool get isNotEmpty => _models.isNotEmpty;
  int get length => _models.length;
  Set<E> toSet() => _models.toSet();
}

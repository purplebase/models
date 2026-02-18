import 'package:riverpod/riverpod.dart';

import '../core/model.dart';
import '../core/types.dart';
import '../filter/request_filter.dart';
import '../source/source.dart';
import '../storage/storage_state.dart';
import '../query/request_notifier.dart';

/// Provider identity cache key.
class _ProviderCacheKey {
  final RequestFilter filter;
  final Source? source;
  final String? subscriptionPrefix;

  _ProviderCacheKey(this.filter, this.source, this.subscriptionPrefix);

  @override
  bool operator ==(Object other) =>
      other is _ProviderCacheKey &&
      other.filter == filter &&
      other.source == source &&
      other.subscriptionPrefix == subscriptionPrefix;

  @override
  int get hashCode => Object.hash(filter, source, subscriptionPrefix);
}

final Map<
    _ProviderCacheKey,
    AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>>
    _typedProviderCache = {};

/// Family of notifier providers, one per request.
/// Manually caching since a factory function is needed to pass the type.
_requestNotifierProvider<E extends Model<dynamic>>(
  RequestFilter<E> filter,
  Source? source,
  String? subscriptionPrefix,
) {
  final cacheKey = _ProviderCacheKey(filter, source, subscriptionPrefix);
  return _typedProviderCache[cacheKey] ??= StateNotifierProvider.autoDispose
      .family<RequestNotifier<E>, StorageState<E>, RequestFilter<E>>((
    ref,
    req,
  ) {
    ref.onDispose(() => _typedProviderCache.remove(cacheKey));
    return RequestNotifier(
      ref,
      filter.toRequest(subscriptionPrefix: subscriptionPrefix),
      source,
    );
  })(filter);
}

/// Query for models of any kind.
///
/// If [source] is not provided, uses [StorageConfiguration.defaultQuerySource].
AutoDisposeStateNotifierProvider<RequestNotifier, StorageState> queryKinds({
  Set<String>? ids,
  Set<int>? kinds,
  Set<String>? authors,
  Map<String, Set<String>>? tags,
  String? search,
  DateTime? since,
  DateTime? until,
  int? limit,
  Source? source,
  String? subscriptionPrefix,
  AndFunction and,
  WhereFunction where,
  SchemaFilter? schemaFilter,
}) {
  final filter = RequestFilter(
    ids: ids,
    kinds: kinds,
    authors: authors,
    tags: tags,
    search: search,
    since: since,
    until: until,
    limit: limit,
    where: where,
    and: and,
    schemaFilter: schemaFilter,
  );
  return _requestNotifierProvider(filter, source, subscriptionPrefix);
}

/// Query for models of a specific type [E].
///
/// If [source] is not provided, uses [StorageConfiguration.defaultQuerySource].
AutoDisposeStateNotifierProvider<RequestNotifier<E>, StorageState<E>>
    query<E extends Model<E>>({
  Set<String>? ids,
  Set<String>? authors,
  Map<String, Set<String>>? tags,
  String? search,
  DateTime? since,
  DateTime? until,
  int? limit,
  Source? source,
  String? subscriptionPrefix,
  WhereFunction<E> where,
  AndFunction<E> and,
  SchemaFilter? schemaFilter,
}) {
  final filter = RequestFilter<E>(
    ids: ids,
    authors: authors,
    tags: tags,
    search: search,
    since: since,
    until: until,
    limit: limit,
    where: _castWhere(where),
    and: _castAnd(and),
    schemaFilter: schemaFilter,
  );
  return _requestNotifierProvider<E>(filter, source, subscriptionPrefix);
}

/// Watch a specific model instance.
///
/// If [source] is not provided, uses [StorageConfiguration.defaultQuerySource].
AutoDisposeStateNotifierProvider<RequestNotifier<E>, StorageState<E>>
    model<E extends Model<E>>(
  E m, {
  Source? source,
  String? subscriptionPrefix,
  AndFunction<E> and,
}) {
  final filter = RequestFilter<E>(ids: {m.id}, and: _castAnd(and));
  return _requestNotifierProvider<E>(filter, source, subscriptionPrefix);
}

AndFunction _castAnd<E extends Model<E>>(AndFunction<E> andFn) {
  return andFn == null ? null : (e) => andFn(e as E);
}

WhereFunction _castWhere<E extends Model<E>>(WhereFunction<E> whereFn) {
  return whereFn == null ? null : (e) => whereFn(e as E);
}

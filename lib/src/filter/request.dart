import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../core/model.dart';
import 'request_filter.dart';

/// Maximum length for subscription ID prefix.
const kMaxPrefixLength = 40;

/// Trims a prefix to fit within the max length.
String _trimPrefix(String prefix, int maxLength) {
  if (prefix.length <= maxLength) return prefix;
  return prefix.substring(0, maxLength);
}

/// A request for fetching Nostr events.
///
/// Contains one or more [RequestFilter]s and a generated subscription ID.
/// The optional [subscriptionPrefix] makes subscription IDs readable
/// for debugging.
class Request<E extends Model<dynamic>> with EquatableMixin {
  static final _random = math.Random();

  final List<RequestFilter<E>> filters;

  /// Subscription ID for this request
  late final String subscriptionId;

  /// Stored explicitly (fixes prefix-matching bug from old implementation).
  /// Always non-null — defaults to a type-based prefix when not provided.
  late final String subscriptionPrefix;

  Request(this.filters, {String? subscriptionPrefix}) {
    this.subscriptionPrefix = subscriptionPrefix ?? _getDefaultPrefix<E>();
    final trimmedPrefix = _trimPrefix(this.subscriptionPrefix, kMaxPrefixLength);
    subscriptionId = '$trimmedPrefix-${_random.nextInt(999999)}';
  }

  /// Get default subscription prefix based on model type
  static String _getDefaultPrefix<T extends Model<dynamic>>() {
    if (<Model<dynamic>>[] is List<T>) {
      return 'sub';
    }
    final typeName = T.toString().toLowerCase();
    return 'sub-$typeName';
  }

  factory Request.fromIds(Iterable<String> ids,
      {String? subscriptionPrefix}) {
    final regularIds = <String>{};
    final filters = <RequestFilter<E>>[];

    for (final id in ids) {
      if (!id.contains(':')) {
        regularIds.add(id);
        continue;
      }
      final [kind, author, ...rest] = id.split(':');
      var filter = RequestFilter<E>(
        kinds: {int.parse(kind)},
        authors: {author},
      );
      if (rest.isNotEmpty && rest.first.isNotEmpty) {
        filter = filter.copyWith(
          tags: {
            '#d': {rest.first},
          },
        );
      }
      filters.add(filter);
    }
    if (regularIds.isNotEmpty) {
      filters.add(RequestFilter(ids: regularIds));
    }
    return Request(filters, subscriptionPrefix: subscriptionPrefix);
  }

  List<Map<String, dynamic>> toMaps() {
    return filters.map((f) => f.toMap()).toList();
  }

  @override
  List<Object?> get props => [filters];

  @override
  String toString() {
    return 'Req[${filters.join(', ')}]';
  }
}

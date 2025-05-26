part of models;

/// A nostr request filter, with additional arguments for querying a [StorageNotifier]
class RequestFilter<E extends Model<dynamic>> extends Equatable {
  static final _random = Random();

  final Set<String> ids;
  final Set<int> kinds;
  final Set<String> authors;
  final Map<String, Set<String>> tags;
  final DateTime? since;
  final DateTime? until;
  final int? limit;
  final String? search;

  // Extra arguments

  /// Provide a specific subscription ID
  late final String subscriptionId;

  /// Total limit including streaming
  final int? queryLimit;

  /// Do not query relays
  final bool remote;

  /// Send request to this relay group
  final String? relayGroup;

  /// Provide additional post-query filtering in Dart
  final WhereFunction where; // do not pass <E>

  /// Watch relationships
  final AndFunction and; // do not pass <E>

  RequestFilter({
    Set<String>? ids,
    Set<int>? kinds,
    Set<String>? authors,
    Map<String, Set<String>>? tags,
    this.since,
    this.until,
    this.limit,
    this.search,

    // Extra arguments
    String? subscriptionId,
    this.queryLimit,
    this.remote = false,
    this.relayGroup,
    this.where,
    this.and,
  })  : ids = ids ?? const {},
        authors = authors ?? const {},
        kinds =
            _isModelOfDynamic<E>() ? kinds ?? const {} : {Model._kindFor<E>()},
        tags = tags ?? const {} {
    // IDs are either regular (64 character) or replaceable and match its regexp
    if (ids != null &&
        ids.any((i) => i.length != 64 && !_kReplaceableRegexp.hasMatch(i))) {
      throw UnsupportedError('Bad ids input: $ids');
    }
    final authorsHex = authors?.map(Utils.hexFromNpub);
    if (authorsHex != null && authorsHex.any((a) => a.length != 64)) {
      throw UnsupportedError('Bad authors input: $authors');
    }
    this.subscriptionId = subscriptionId ?? 'sub-${_random.nextInt(999999)}';
  }

  factory RequestFilter.fromMap(Map<String, dynamic> map) {
    return RequestFilter<E>(
      ids: {...?map['ids']},
      kinds:
          _isModelOfDynamic<E>() ? {...?map['kinds']} : {Model._kindFor<E>()},
      authors: {...?map['authors']},
      tags: {
        for (final e in map.entries)
          if (e.key.startsWith('#')) e.key: {...e.value}
      },
      search: map['search'],
      since: map['since'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['since'] * 1000)
          : null,
      until: map['until'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['until'] * 1000)
          : null,
      limit: map['limit'],
    );
  }

  factory RequestFilter.fromReplaceable(String addressableId) {
    if (!addressableId.contains(':')) {
      throw UnsupportedError('Addressable ID must contain `:`');
    }
    final [kind, author, ...rest] = addressableId.split(':');
    var req = RequestFilter<E>(
      kinds: {int.parse(kind)},
      authors: {author},
    );
    if (rest.isNotEmpty && rest.first.isNotEmpty) {
      req = req.copyWith(tags: {
        '#d': {rest.first}
      });
    }
    return req;
  }

  static bool _isModelOfDynamic<E extends Model<dynamic>>() =>
      <Model<dynamic>>[] is List<E>;

  Map<String, dynamic> toMap() {
    return {
      if (ids.isNotEmpty) 'ids': ids.sorted(),
      if (kinds.isNotEmpty) 'kinds': kinds.sorted((i, j) => i.compareTo(j)),
      if (authors.isNotEmpty) 'authors': authors.sorted(),
      for (final e in tags.entries.sortedBy((e) => e.key))
        if (e.value.isNotEmpty) e.key: e.value.sorted(),
      if (since != null) 'since': since!.toSeconds(),
      if (until != null) 'until': until!.toSeconds(),
      if (limit != null) 'limit': limit,
      if (search != null) 'search': search,
    };
  }

  RequestFilter<E> copyWith({
    Set<String>? ids,
    Set<String>? authors,
    Set<int>? kinds,
    Map<String, Set<String>>? tags,
    String? search,
    DateTime? since,
    DateTime? until,
    int? limit,
    int? queryLimit,
    bool? remote,
  }) {
    return RequestFilter(
      ids: ids ?? this.ids,
      authors: authors ?? this.authors,
      kinds: kinds ?? this.kinds,
      tags: tags ?? this.tags,
      search: search ?? this.search,
      since: since ?? this.since,
      until: until ?? this.until,
      limit: limit ?? this.limit,
      // Extra arguments
      subscriptionId: subscriptionId,
      queryLimit: queryLimit,
      remote: remote ?? this.remote,
      relayGroup: relayGroup,
      where: where,
      and: and,
    );
  }

  @override
  List<Object?> get props =>
      [ids, kinds, authors, tags, search, since, until, limit];

  @override
  String toString() {
    return toMap().toString();
  }
}

final _kReplaceableRegexp = RegExp(r'(\d+):([0-9a-f]{64}):(.*)');

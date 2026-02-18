import 'remote_source.dart';

/// Source configuration that queries both local storage and remote relays.
final class LocalAndRemoteSource extends RemoteSource {
  /// Cache duration for author+kind queries on replaceable events.
  ///
  /// When set and the query is cacheable (author+kind only, replaceable kinds,
  /// no tags/ids/search/until), fresh local data will be returned without
  /// hitting remote relays if fetched within this duration.
  ///
  /// Note: When [cachedFor] is set, [stream] is forced to `false`.
  final Duration? cachedFor;

  const LocalAndRemoteSource({
    super.relays,
    super.stream = true,
    this.cachedFor,
  });

  /// When [cachedFor] is set, streaming is disabled.
  @override
  bool get stream => cachedFor != null ? false : super.stream;

  @override
  LocalAndRemoteSource copyWith({
    dynamic relays,
    bool? stream,
    Duration? cachedFor,
  }) {
    return LocalAndRemoteSource(
      relays: relays ?? this.relays,
      stream: stream ?? super.stream,
      cachedFor: cachedFor ?? this.cachedFor,
    );
  }

  @override
  List<Object?> get props => [
        relays,
        stream,
        cachedFor,
      ];

  @override
  String toString() {
    return 'LocalAnd${super.toString()}';
  }
}

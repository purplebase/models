part of models;

abstract class StorageNotifier extends StateNotifier<StorageSignal> {
  StorageNotifier() : super(null);
  late StorageConfiguration config;

  // - Need to place this cache here as its accessed by
  // both request notifiers and relationships
  // - Keep it as list and it will retain order from database query
  // - Format: {'subId': {RequestFilter(1): [events1], RequestFilter(2): [events2]}}
  // - It's necessary to keep it per subscription ID as request notifiers
  // remove caches when disposed, but should only be theirs
  @protected
  final Map<String, Map<RequestFilter, List<Event>>> requestCache = {};

  @mustCallSuper
  Future<void> initialize(StorageConfiguration config) async {
    this.config = config;
  }

  /// Query storage asynchronously
  /// Passing [remote]=`true` hits relays only until EOSE
  Future<List<Event>> query(RequestFilter req,
      {bool applyLimit = true, Set<String>? onIds});

  /// Query storage asynchronously
  /// [remote] is ignored and always false
  List<Event> querySync(RequestFilter req,
      {bool applyLimit = true, Set<String>? onIds});

  /// Save events to storage, use [publish] to send to relays
  /// Specifying [relayGroup] or fall back to default group
  Future<void> save(Set<Event> events,
      {String? relayGroup, bool publish = false});

  /// Trigger a fetch on relays, returns pre-EOSE events
  /// but streams in the background
  Future<Set<Event>> fetch(RequestFilter req);

  /// Cancel any subscriptions for [req]
  Future<void> cancel(RequestFilter req);

  /// Remove all events from storage, or those matching [req]
  Future<void> clear([RequestFilter? req]);
}

final storageNotifierProvider =
    StateNotifierProvider<StorageNotifier, StorageSignal>(
        DummyStorageNotifier.new);

typedef StorageSignal = (Set<String>, ResponseMetadata)?;

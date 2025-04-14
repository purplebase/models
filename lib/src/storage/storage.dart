import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';

abstract class StorageNotifier extends StateNotifier<StorageSignal> {
  StorageNotifier() : super(null);
  late StorageConfiguration config;

  // - Need to place this cache here as its accessed by
  // both request notifiers and relationships
  // - Keep it as list and it will retain order from database query
  // - Format: {'subId': {RequestFilter(1): [events1], RequestFilter(2): [events2]}}
  // - It's necessary to keep it per subscription ID as request notifiers
  // remove caches when disposed, but should only be theirs
  final Map<String, Map<RequestFilter, List<Event>>> requestCache = {};

  Future<void> initialize(StorageConfiguration config) async {
    this.config = config;
  }

  Future<List<Event>> query(RequestFilter req,
      {bool applyLimit = true, Set<String>? onIds});

  List<Event> querySync(RequestFilter req,
      {bool applyLimit = true, Set<String>? onIds});

  Future<void> save(Set<Event> events,
      {String? relayGroup, bool publish = true});

  Future<int> count();

  Future<void> send(RequestFilter req);

  /// Cancels any subscriptions for [req]
  Future<void> cancel(RequestFilter req);

  Future<void> clear([RequestFilter? req]);
}

final storageNotifierProvider =
    StateNotifierProvider<StorageNotifier, StorageSignal>(
        DummyStorageNotifier.new);

typedef StorageSignal = (Set<String>, ResponseMetadata)?;

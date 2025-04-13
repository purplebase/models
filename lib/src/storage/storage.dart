import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';

abstract class StorageNotifier extends StateNotifier<StorageSignal> {
  StorageNotifier() : super(null);
  late StorageConfiguration config;

  // Need to place this cache here as its accessed by
  // both request notifiers and relationships
  final Map<RequestFilter, List<Event>> requestCache = {};

  Future<void> initialize(StorageConfiguration config) async {
    this.config = config;
  }

  Future<List<Event>> query(RequestFilter req, {bool applyLimit = true});

  Future<void> save(Set<Event> events,
      {String? relayGroup, bool publish = true});

  Future<void> send(RequestFilter req);

  /// Cancels any subscriptions for [req]
  Future<void> cancel(RequestFilter req);

  Future<void> clear([RequestFilter? req]);
}

final storageNotifierProvider =
    StateNotifierProvider<StorageNotifier, StorageSignal>(
        DummyStorageNotifier.new);

typedef StorageSignal = (Set<String>, ResponseMetadata)?;

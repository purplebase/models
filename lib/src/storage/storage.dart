import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';

abstract class StorageNotifier extends StateNotifier<StorageSignal> {
  StorageNotifier() : super(StorageSignal());
  late StorageConfiguration config;

  Future<void> initialize(StorageConfiguration config) async {
    this.config = config;
  }

  Future<List<Event>> query(RequestFilter req, {bool applyLimit = true});

  /// Ideally to be used for must-have sync interfaces such relationships
  /// upon widget first load, and tests. Prefer [query] otherwise.
  List<Event> querySync(RequestFilter req, {bool applyLimit = true});

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

class StorageSignal {
  final (Set<String>, ResponseMetadata)? record;
  StorageSignal([this.record]);
}

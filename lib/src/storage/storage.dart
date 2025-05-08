part of models;

/// Storage interface that notifies upon updates
/// NOTE: Implementations SHOULD be singletons
abstract class StorageNotifier extends StateNotifier<Set<String>?> {
  StorageNotifier() : super(null);
  late StorageConfiguration config;

  // - Need to place this cache here as its accessed by
  // both request notifiers and relationships
  // - Keep it as list and it will retain order from database query
  // - Format: {'subId': {RequestFilter(1): [models1], RequestFilter(2): [models2]}}
  // - It's necessary to keep it per subscription ID as request notifiers
  // remove caches when disposed, but should only be theirs
  @protected
  final Map<String, Map<RequestFilter, List<Model>>> requestCache = {};

  /// Storage initialization, sets up [config] and registers types,
  /// `super` MUST be called
  @mustCallSuper
  Future<void> initialize(StorageConfiguration config) async {
    // Regular
    Model.register(kind: 0, constructor: Profile.fromMap);
    Model.register(kind: 1, constructor: Note.fromMap);
    Model.register(kind: 3, constructor: ContactList.fromMap);
    Model.register(kind: 4, constructor: DirectMessage.fromMap);
    Model.register(kind: 7, constructor: Reaction.fromMap);
    Model.register(kind: 9, constructor: ChatMessage.fromMap);
    Model.register(kind: 1063, constructor: FileMetadata.fromMap);
    Model.register(kind: 1111, constructor: Comment.fromMap);
    Model.register(kind: 9734, constructor: ZapRequest.fromMap);
    Model.register(kind: 9735, constructor: Zap.fromMap);

    // Replaceable
    Model.register(kind: 10222, constructor: Community.fromMap);

    // Ephemeral
    Model.register(kind: 24133, constructor: BunkerAuthorization.fromMap);
    Model.register(kind: 24242, constructor: BlossomAuthorization.fromMap);

    // Parameterized replaceable
    Model.register(kind: 30023, constructor: Article.fromMap);
    Model.register(kind: 30063, constructor: Release.fromMap);
    Model.register(kind: 30222, constructor: TargetedPublication.fromMap);
    Model.register(kind: 30267, constructor: AppCurationSet.fromMap);
    Model.register(kind: 32267, constructor: App.fromMap);

    this.config = config;
  }

  /// Query storage asynchronously
  /// Passing [remote]=`true` hits relays only until EOSE
  Future<List<E>> query<E extends Model<dynamic>>(RequestFilter<E> req,
      {bool applyLimit = true, Set<String>? onIds});

  /// Query storage asynchronously
  /// [remote] is ignored and always false
  List<E> querySync<E extends Model<dynamic>>(RequestFilter<E> req,
      {bool applyLimit = true, Set<String>? onIds});

  /// Save models to storage, use [publish] to send to relays
  /// Specifying [relayGroup] or fall back to default group
  Future<void> save(Set<Model<dynamic>> models,
      {String? relayGroup, bool publish = false});

  /// Trigger a fetch on relays, returns pre-EOSE models
  /// but streams in the background
  Future<Set<E>> fetch<E extends Model<dynamic>>(RequestFilter<E> req);

  /// Cancel any subscriptions for [req], this cannot be
  /// done on [dispose] as we need to pass the req
  void cancel(RequestFilter req);

  /// Remove all models from storage, or those matching [req]
  Future<void> clear([RequestFilter? req]);
}

final storageNotifierProvider =
    StateNotifierProvider<StorageNotifier, Set<String>?>(
        DummyStorageNotifier.new);

// State

sealed class StorageState<E extends Model<dynamic>> with EquatableMixin {
  final List<E> models;
  const StorageState(this.models);

  @override
  List<Object?> get props => [models];

  @override
  String toString() {
    return '[$runtimeType] $models';
  }
}

final class StorageLoading<E extends Model<dynamic>> extends StorageState<E> {
  StorageLoading(super.models);
}

final class StorageData<E extends Model<dynamic>> extends StorageState<E> {
  StorageData(super.models);
}

final class StorageError<E extends Model<dynamic>> extends StorageState<E> {
  final Exception exception;
  final StackTrace? stackTrace;
  StorageError(super.models, {required this.exception, this.stackTrace});
}

part of models;

/// Storage interface that notifies upon updates
/// NOTE: Implementations SHOULD be singletons
abstract class StorageNotifier extends StateNotifier<StorageState> {
  StorageNotifier() : super(InternalStorageData());
  late StorageConfiguration config;

  // The request cache is crucial for widgets
  // to have sync access to relationships!
  // - Need to place this cache here as its accessed by
  //   both request notifiers (writes) and relationships (reads)
  // - Keep it as list and it will retain order from database query
  // - Format: {'subId': {Request(1): [models1], Request(2): [models2]}}
  // - It's necessary to keep it per subscription ID as request notifiers
  // remove caches when disposed, but should only be theirs
  @protected
  final Map<String, Map<Request, List<Model>>> requestCache = {};

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
    Model.register(kind: 3063, constructor: SoftwareAsset.fromMap);
    Model.register(kind: 1111, constructor: Comment.fromMap);
    Model.register(kind: 9734, constructor: ZapRequest.fromMap);
    Model.register(kind: 9735, constructor: Zap.fromMap);

    // DVM
    Model.register(kind: 5312, constructor: VerifyReputationRequest.fromMap);
    Model.register(kind: 6312, constructor: VerifyReputationResponse.fromMap);
    Model.register(kind: 7000, constructor: DVMError.fromMap);

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

  /// Query storage asynchronously.
  /// [source] defaults to [RemoteSource], which fetches from local storage and relays
  /// For errors, listen to this notifier and filter for [StorageError]
  Future<List<E>> query<E extends Model<dynamic>>(Request<E> req,
      {Source? source, Set<String>? onIds});

  /// Query storage asynchronously, always local
  List<E> querySync<E extends Model<dynamic>>(Request<E> req,
      {Set<String>? onIds});

  /// Save models to local storage in one transaction.
  /// For errors, listen to this notifier and filter for [StorageError]
  Future<bool> save(Set<Model<dynamic>> models);

  /// Sends to relays and waits for response.
  /// For errors, listen to this notifier and filter for [StorageError]
  Future<PublishResponse> publish(Set<Model<dynamic>> models,
      {RemoteSource? source});

  /// Remove all models from local storage (or those matching [req]).
  /// For errors, listen to this notifier and filter for [StorageError]
  Future<void> clear([Request? req]);

  /// Cancel any subscriptions for [req] (this cannot be
  /// done on [dispose] as we need to pass the request).
  Future<void> cancel(Request req);
}

final storageNotifierProvider =
    StateNotifierProvider<StorageNotifier, StorageState>(
        DummyStorageNotifier.new);

extension RefExt on Ref {
  StorageNotifier get storage => read(storageNotifierProvider.notifier);
}

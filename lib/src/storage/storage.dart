part of models;

/// Storage interface that notifies upon updates
/// NOTE: Implementations SHOULD be singletons
abstract class StorageNotifier extends StateNotifier<StorageState> {
  StorageNotifier() : super(StorageLoading([]));
  late StorageConfiguration config;

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
    Model.register(kind: 11, constructor: RelayInfo.fromMap);
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
    Model.register(kind: 30078, constructor: CustomData.fromMap);
    Model.register(kind: 30222, constructor: TargetedPublication.fromMap);
    Model.register(kind: 30267, constructor: AppCurationSet.fromMap);
    Model.register(kind: 32267, constructor: App.fromMap);
    Model.register(kind: 6, constructor: Repost.fromMap);
    Model.register(kind: 16, constructor: GenericRepost.fromMap);

    this.config = config;
  }

  /// Query storage asynchronously, always local
  List<E> querySync<E extends Model<dynamic>>(Request<E> req);

  /// Query storage asynchronously.
  /// By default fetches from local storage and relays.
  /// For errors, listen to this notifier and filter for [StorageError]
  Future<List<E>> query<E extends Model<dynamic>>(Request<E> req,
      {Source source = const LocalAndRemoteSource(stream: false)});

  /// Save models to local storage in one transaction.
  /// For errors, listen to this notifier and filter for [StorageError]
  Future<bool> save(Set<Model<dynamic>> models);

  /// Sends to relays and waits for response.
  /// For errors, listen to this notifier and filter for [StorageError]
  Future<PublishResponse> publish(Set<Model<dynamic>> models,
      {RemoteSource source = const RemoteSource()});

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

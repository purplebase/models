part of models;

/// Storage interface that notifies upon updates
abstract class StorageNotifier extends StateNotifier<StorageState> {
  StorageNotifier() : super(StorageLoading([]));
  late StorageConfiguration config;

  bool isInitialized = false;

  /// Storage initialization, sets up [config] and registers types,
  /// `super` MUST be called
  @mustCallSuper
  Future<void> initialize(StorageConfiguration config) async {
    if (isInitialized) return;

    // Regular
    Model.register(
      kind: 0,
      constructor: Profile.fromMap,
      partialConstructor: PartialProfile.fromMap,
    );
    Model.register(
      kind: 1,
      constructor: Note.fromMap,
      partialConstructor: PartialNote.fromMap,
    );
    Model.register(
      kind: 3,
      constructor: ContactList.fromMap,
      partialConstructor: PartialContactList.fromMap,
    );
    Model.register(
      kind: 4,
      constructor: DirectMessage.fromMap,
      partialConstructor: PartialDirectMessage.fromMap,
    );
    Model.register(
      kind: 5,
      constructor: EventDeletionRequest.fromMap,
      partialConstructor: PartialEventDeletionRequest.fromMap,
    );
    Model.register(
      kind: 6,
      constructor: Repost.fromMap,
      partialConstructor: PartialRepost.fromMap,
    );
    Model.register(
      kind: 7,
      constructor: Reaction.fromMap,
      partialConstructor: PartialReaction.fromMap,
    );
    Model.register(
      kind: 9,
      constructor: ChatMessage.fromMap,
      partialConstructor: PartialChatMessage.fromMap,
    );
    Model.register(kind: 11, constructor: RelayInfo.fromMap);
    Model.register(
      kind: 16,
      constructor: GenericRepost.fromMap,
      partialConstructor: PartialGenericRepost.fromMap,
    );
    Model.register(
      kind: 20,
      constructor: Picture.fromMap,
      partialConstructor: PartialPicture.fromMap,
    );
    Model.register(
      kind: 1063,
      constructor: FileMetadata.fromMap,
      partialConstructor: PartialFileMetadata.fromMap,
    );
    Model.register(
      kind: 3063,
      constructor: SoftwareAsset.fromMap,
      partialConstructor: PartialSoftwareAsset.fromMap,
    );
    Model.register(
      kind: 1111,
      constructor: Comment.fromMap,
      partialConstructor: PartialComment.fromMap,
    );
    Model.register(
      kind: 1984,
      constructor: Report.fromMap,
      partialConstructor: PartialReport.fromMap,
    );
    Model.register(
      kind: 9734,
      constructor: ZapRequest.fromMap,
      partialConstructor: PartialZapRequest.fromMap,
    );
    Model.register(
      kind: 9735,
      constructor: Zap.fromMap,
      partialConstructor: PartialZap.fromMap,
    );
    Model.register(
      kind: 9802,
      constructor: Highlight.fromMap,
      partialConstructor: PartialHighlight.fromMap,
    );

    // DVM
    Model.register(
      kind: 5312,
      constructor: VerifyReputationRequest.fromMap,
      partialConstructor: PartialVerifyReputationRequest.fromMap,
    );
    Model.register(kind: 6312, constructor: VerifyReputationResponse.fromMap);
    Model.register(kind: 7000, constructor: DVMError.fromMap);

    // Replaceable
    Model.register(
      kind: 10222,
      constructor: Community.fromMap,
      partialConstructor: PartialCommunity.fromMap,
    );

    // Ephemeral
    Model.register(
      kind: 24133,
      constructor: BunkerAuthorization.fromMap,
      partialConstructor: PartialBunkerAuthorization.fromMap,
    );
    Model.register(
      kind: 24242,
      constructor: BlossomAuthorization.fromMap,
      partialConstructor: PartialBlossomAuthorization.fromMap,
    );

    // NIP-65: Relay List Metadata
    Model.register(
      kind: 10002,
      constructor: RelayListMetadata.fromMap,
      partialConstructor: PartialRelayListMetadata.fromMap,
    );

    // NIP-51: User Lists (Replaceable)
    Model.register(
      kind: 10000,
      constructor: MuteList.fromMap,
      partialConstructor: PartialMuteList.fromMap,
    );
    Model.register(
      kind: 10001,
      constructor: PinList.fromMap,
      partialConstructor: PartialPinList.fromMap,
    );
    Model.register(
      kind: 10003,
      constructor: BookmarkList.fromMap,
      partialConstructor: PartialBookmarkList.fromMap,
    );

    // Parameterized replaceable
    Model.register(
      kind: 30023,
      constructor: Article.fromMap,
      partialConstructor: PartialArticle.fromMap,
    );
    Model.register(
      kind: 30063,
      constructor: Release.fromMap,
      partialConstructor: PartialRelease.fromMap,
    );
    Model.register(
      kind: 30078,
      constructor: CustomData.fromMap,
      partialConstructor: PartialCustomData.fromMap,
    );
    Model.register(
      kind: 30222,
      constructor: TargetedPublication.fromMap,
      partialConstructor: PartialTargetedPublication.fromMap,
    );
    // NIP-51: Parameterizable Sets
    Model.register(
      kind: 30000,
      constructor: FollowSets.fromMap,
      partialConstructor: PartialFollowSets.fromMap,
    );
    Model.register(
      kind: 30267,
      constructor: AppCurationSet.fromMap,
      partialConstructor: PartialAppCurationSet.fromMap,
    );
    Model.register(
      kind: 32267,
      constructor: App.fromMap,
      partialConstructor: PartialApp.fromMap,
    );

    // NIP-52: Calendar Events
    Model.register(
      kind: 31922,
      constructor: DateBasedCalendarEvent.fromMap,
      partialConstructor: PartialDateBasedCalendarEvent.fromMap,
    );
    Model.register(
      kind: 31923,
      constructor: TimeBasedCalendarEvent.fromMap,
      partialConstructor: PartialTimeBasedCalendarEvent.fromMap,
    );
    Model.register(
      kind: 31924,
      constructor: Calendar.fromMap,
      partialConstructor: PartialCalendar.fromMap,
    );
    Model.register(
      kind: 31925,
      constructor: CalendarEventRSVP.fromMap,
      partialConstructor: PartialCalendarEventRSVP.fromMap,
    );

    // NWC (Nostr Wallet Connect) models
    Model.register(
      kind: 13194,
      constructor: NwcInfo.fromMap,
      partialConstructor: PartialNwcInfo.fromMap,
    );
    Model.register(
      kind: 23194,
      constructor: NwcRequest.fromMap,
      partialConstructor: PartialNwcRequest.fromMap,
    );
    Model.register(
      kind: 23195,
      constructor: NwcResponse.fromMap,
      partialConstructor: PartialNwcResponse.fromMap,
    );
    Model.register(
      kind: 23196,
      constructor: NwcNotification.fromMap,
      partialConstructor: PartialNwcNotification.fromMap,
    );

    this.config = config;
  }

  /// Query storage asynchronously, always local
  List<E> querySync<E extends Model<dynamic>>(Request<E> req);

  /// Query storage asynchronously.
  /// By default fetches from local storage and relays.
  /// For errors, listen to this notifier and filter for [StorageError]
  Future<List<E>> query<E extends Model<dynamic>>(
    Request<E> req, {
    Source? source,
  });

  /// Save models to local storage in one transaction.
  /// For errors, listen to this notifier and filter for [StorageError]
  Future<bool> save(Set<Model<dynamic>> models);

  /// Sends to relays and waits for response.
  /// For errors, listen to this notifier and filter for [StorageError]
  Future<PublishResponse> publish(
    Set<Model<dynamic>> models, {
    RemoteSource source = const RemoteSource(),
  });

  /// Remove all models from local storage (or those matching [req]).
  /// For errors, listen to this notifier and filter for [StorageError]
  Future<void> clear([Request? req]);

  /// Delete all database related files in the filesystem
  Future<void> obliterate();

  /// Cancel any subscriptions for [req] (this cannot be
  /// done on dispose as we need to pass the request).
  Future<void> cancel(Request req);

  @override
  void dispose() {
    if (isInitialized) {
      super.dispose();
    }
  }
}

final storageNotifierProvider =
    StateNotifierProvider<StorageNotifier, StorageState>(
      DummyStorageNotifier.new,
    );

extension RefExt on Ref {
  StorageNotifier get storage => read(storageNotifierProvider.notifier);
}

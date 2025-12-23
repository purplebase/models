part of models;

/// Storage interface that notifies upon updates
abstract class StorageNotifier extends StateNotifier<StorageState> {
  StorageNotifier(this.ref) : super(StorageLoading([]));

  final Ref ref;
  late StorageConfiguration config;

  bool isInitialized = false;

  /// Cache version counter for relationship query caching.
  /// Increments on any storage mutation, invalidating cached query results.
  int _cacheVersion = 0;
  int get cacheVersion => _cacheVersion;

  /// Call this in subclass mutation methods (save, clear, etc.)
  /// to invalidate relationship query caches.
  @protected
  void invalidateQueryCache() => _cacheVersion++;

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
      kind: 21,
      constructor: Video.fromMap,
      partialConstructor: PartialVideo.fromMap,
    );
    Model.register(
      kind: 22,
      constructor: ShortFormPortraitVideo.fromMap,
      partialConstructor: PartialShortFormPortraitVideo.fromMap,
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
      kind: 1222,
      constructor: VoiceMessage.fromMap,
      partialConstructor: PartialVoiceMessage.fromMap,
    );
    Model.register(
      kind: 1244,
      constructor: VoiceMessageComment.fromMap,
      partialConstructor: PartialVoiceMessageComment.fromMap,
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

    // Relay Lists (1xxxx kinds)
    // NIP-65: Social relay list
    Model.register(
      kind: 10002,
      constructor: SocialRelayList.fromMap,
      partialConstructor: PartialSocialRelayList.fromMap,
    );
    // App catalog relay list
    Model.register(
      kind: 10067,
      constructor: AppCatalogRelayList.fromMap,
      partialConstructor: PartialAppCatalogRelayList.fromMap,
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
      kind: 30003,
      constructor: BookmarkSet.fromMap,
      partialConstructor: PartialBookmarkSet.fromMap,
    );
    Model.register(
      kind: 30267,
      constructor: AppStack.fromMap,
      partialConstructor: PartialAppStack.fromMap,
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

  /// Resolve relay URLs from label with signed RelayList precedence.
  ///
  /// Resolution order:
  /// 1. null → empty set (TODO: outbox lookup)
  /// 2. Starts with ws:// or wss:// → ad-hoc relay URL
  /// 3. Label → query active signer's signed RelayList by kind, fallback to config.defaultRelays
  ///
  /// Iterables are also supported: {'social', 'wss://relay.example.com'} will
  /// resolve the 'social' label and include the ad-hoc URL.
  ///
  /// Reactive: When a signed RelayList is updated, subsequent calls will use new relays.
  Future<Set<String>> resolveRelays(dynamic relays) async {
    if (relays == null) {
      // TODO: Implement outbox lookup (NIP-65)
      return _resolveRelayIterable(config.defaultRelays['default'] ?? const {});
    }

    // Iterable input (List/Set/etc.) of relay targets; resolve each.
    if (relays is Iterable && relays is! String) {
      return _resolveRelayIterable(relays);
    }

    final relayValue = relays.toString();

    // Ad-hoc relay URL
    if (relayValue.startsWith('ws://') || relayValue.startsWith('wss://')) {
      final normalized = _normalizeRelayUrl(relayValue);
      return normalized != null ? {normalized} : {};
    }

    // Label lookup - get kind from registry
    final kind = RelayList.labels[relayValue];
    if (kind != null) {
      return await _resolveByKind(kind, relayValue);
    }

    // Unknown label - check defaults for forward compatibility
    return _resolveRelayIterable(config.defaultRelays[relayValue] ?? const {});
  }

  /// Resolve a collection of relay targets (URLs or labels) into relay URLs.
  /// Each item is either:
  /// - A URL (contains ://) → normalized directly
  /// - A relay group label → looked up in config.defaultRelays
  Set<String> _resolveRelayIterable(Iterable relays) {
    final resolved = <String>{};
    for (final relay in relays) {
      final relayStr = relay.toString();

      // Check if it's a URL (has scheme separator)
      if (relayStr.contains('://')) {
        final normalized = _normalizeRelayUrl(relayStr);
        if (normalized != null) {
          resolved.add(normalized);
        }
      } else {
        // It's a label - look up in defaultRelays
        final groupUrls = config.defaultRelays[relayStr];
        if (groupUrls != null) {
          for (final url in groupUrls) {
            final normalized = _normalizeRelayUrl(url.toString());
            if (normalized != null) {
              resolved.add(normalized);
            }
          }
        }
      }
    }
    return resolved;
  }

  /// Resolve relays by querying for a specific RelayList kind
  Future<Set<String>> _resolveByKind(int kind, String label) async {
    final activePubkey = ref.read(Signer.activePubkeyProvider);

    if (activePubkey != null) {
      // Query local storage for signed relay list of this kind
      final results = await query(
        RequestFilter(authors: {activePubkey}, kinds: {kind}).toRequest(),
        source: LocalSource(),
      );

      if (results.isNotEmpty && results.first is RelayList) {
        return _resolveRelayIterable((results.first as RelayList).relays);
      }
    }

    // Fall back to defaults (by label)
    return _resolveRelayIterable(config.defaultRelays[label] ?? const {});
  }

  /// Query storage asynchronously, always local
  List<E> querySync<E extends Model<dynamic>>(Request<E> req);

  /// Query storage asynchronously.
  /// By default fetches from local storage and relays.
  /// For errors, listen to this notifier and filter for [StorageError]
  Future<List<E>> query<E extends Model<dynamic>>(
    Request<E> req, {
    Source? source,
    String? subscriptionPrefix,
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

  /// Helper: Check if a kind represents an encrypted event type.
  static bool isEncryptedKind(int kind) {
    return kind == 4 || // DirectMessage
        kind == 10000 || // MuteList
        kind == 10001 || // PinList
        kind == 30003 || // BookmarkSet
        kind == 30267 || // AppStack
        kind == 13194 || // NwcInfo
        kind == 23194 || // NwcRequest
        kind == 23195 || // NwcResponse
        kind == 23196; // NwcNotification
  }

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

/// Normalize and sanitize a single relay URL string.
/// Returns null for invalid URLs (no host, contains comma, parse errors).
String? _normalizeRelayUrl(String url) {
  // Remove if contains comma
  if (url.contains(',')) return null;

  try {
    final uri = Uri.parse(url.trim());

    // Must have a valid host - reject bare strings like 'social'
    if (uri.host.isEmpty) return null;

    // Only accept ws:// or wss:// schemes
    final scheme = (uri.scheme == 'ws' || uri.scheme == 'wss')
        ? uri.scheme
        : 'wss';

    // Drop default ports (ws:80, wss:443) to keep canonical form.
    int? port = uri.hasPort ? uri.port : null;
    if ((scheme == 'ws' && (port == null || port == 80)) ||
        (scheme == 'wss' && (port == null || port == 443))) {
      port = null;
    }

    // Keep consistent trailing slash logic - remove if present
    final path = uri.path == '/' ? '' : uri.path;

    return Uri(
      scheme: scheme,
      host: uri.host,
      port: port,
      path: path,
      query: uri.query.isEmpty ? null : uri.query,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    ).toString();
  } catch (_) {
    // Could not parse URI, remove from list
    return null;
  }
}

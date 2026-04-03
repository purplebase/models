import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';

import '../core/model.dart';
import '../filter/request.dart';
import '../filter/request_filter.dart';
import '../source/source.dart';
import '../source/remote_source.dart';
import '../signer/signer.dart';
import '../utils/utils.dart';
import 'storage_state.dart';
import 'storage_configuration.dart';

// Forward imports for model registration
import '../models/profile.dart';
import '../models/note.dart';
import '../models/contact_list.dart';
import '../models/direct_message.dart';
import '../models/event_deletion.dart';
import '../models/repost.dart';
import '../models/reaction.dart';
import '../models/chat_message.dart';
import '../models/generic_repost.dart';
import '../models/picture.dart';
import '../models/video.dart';
import '../models/poll_response.dart';
import '../models/poll.dart';
import '../models/file_metadata.dart';
import '../models/asset.dart';
import '../models/comment.dart';
import '../models/voice_message.dart';
import '../models/reporting.dart';
import '../models/zap.dart';
import '../models/highlight.dart';
import '../models/verify_reputation_dvm.dart';
import '../models/community.dart';
import '../models/bunker_authorization.dart';
import '../models/blossom_authorization.dart';
import '../models/relay_list.dart';
import '../models/mute_list.dart';
import '../models/pin_list.dart';
import '../models/article.dart';
import '../models/release.dart';
import '../models/custom_data.dart';
import '../models/targeted_publication.dart';
import '../models/follow_sets.dart';
import '../models/bookmark_set.dart';
import '../models/app_stack.dart';
import '../models/app.dart';
import '../models/calendar_events.dart';
import '../models/nwc.dart';

/// Storage interface that notifies upon updates.
abstract class StorageNotifier extends StateNotifier<StorageState> {
  StorageNotifier(this.ref) : super(StorageLoading([]));

  final Ref ref;
  late StorageConfiguration config;

  bool isInitialized = false;

  /// Cache version counter for relationship query caching.
  int _cacheVersion = 0;
  int get cacheVersion => _cacheVersion;

  /// Cache timestamps for author+kind queries with cachedFor.
  final Map<String, DateTime> _queryCacheTimestamps = {};

  @protected
  void invalidateQueryCache() => _cacheVersion++;

  /// Check if a query result is still fresh based on cachedFor duration.
  bool isCacheValid(Request req, Duration cachedFor) {
    final cacheKey = _generateCacheKey(req);
    if (cacheKey == null) return false;
    final cachedAt = _queryCacheTimestamps[cacheKey];
    if (cachedAt == null) return false;
    return DateTime.now().difference(cachedAt) < cachedFor;
  }

  void updateCacheTimestamp(Request req) {
    final cacheKey = _generateCacheKey(req);
    if (cacheKey != null) {
      _queryCacheTimestamps[cacheKey] = DateTime.now();
    }
  }

  String? _generateCacheKey(Request req) {
    if (req.filters.isEmpty) return null;

    final allAuthors = <String>{};
    final allKinds = <int>{};

    for (final filter in req.filters) {
      if (filter.ids.isNotEmpty ||
          filter.tags.isNotEmpty ||
          filter.search != null ||
          filter.since != null ||
          filter.until != null) {
        return null;
      }
      allAuthors.addAll(filter.authors);
      allKinds.addAll(filter.kinds);
    }

    if (allAuthors.isEmpty && allKinds.isEmpty) return null;

    for (final kind in allKinds) {
      if (!Utils.isEventReplaceable(kind)) return null;
    }

    final sortedAuthors = allAuthors.toList()..sort();
    final sortedKinds = allKinds.toList()..sort();
    return '${sortedAuthors.join(',')}:${sortedKinds.join(',')}';
  }

  @protected
  void invalidateCacheForModels(Iterable<Model<dynamic>> models) {
    _queryCacheTimestamps.clear();
  }

  /// Storage initialization, sets up [config] and registers types.
  @mustCallSuper
  Future<void> initialize(StorageConfiguration config) async {
    if (isInitialized) return;

    // Regular
    Model.register(kind: 0, constructor: Profile.fromMap, partialConstructor: PartialProfile.fromMap);
    Model.register(kind: 1, constructor: Note.fromMap, partialConstructor: PartialNote.fromMap);
    Model.register(kind: 3, constructor: ContactList.fromMap, partialConstructor: PartialContactList.fromMap);
    Model.register(kind: 4, constructor: DirectMessage.fromMap, partialConstructor: PartialDirectMessage.fromMap);
    Model.register(kind: 5, constructor: EventDeletionRequest.fromMap, partialConstructor: PartialEventDeletionRequest.fromMap);
    Model.register(kind: 6, constructor: Repost.fromMap, partialConstructor: PartialRepost.fromMap);
    Model.register(kind: 7, constructor: Reaction.fromMap, partialConstructor: PartialReaction.fromMap);
    Model.register(kind: 9, constructor: ChatMessage.fromMap, partialConstructor: PartialChatMessage.fromMap);
    Model.register(kind: 16, constructor: GenericRepost.fromMap, partialConstructor: PartialGenericRepost.fromMap);
    Model.register(kind: 20, constructor: Picture.fromMap, partialConstructor: PartialPicture.fromMap);
    Model.register(kind: 21, constructor: Video.fromMap, partialConstructor: PartialVideo.fromMap);
    Model.register(kind: 22, constructor: ShortFormPortraitVideo.fromMap, partialConstructor: PartialShortFormPortraitVideo.fromMap);
    Model.register(kind: 1018, constructor: PollResponse.fromMap, partialConstructor: PartialPollResponse.fromMap);
    Model.register(kind: 1068, constructor: Poll.fromMap, partialConstructor: PartialPoll.fromMap);
    Model.register(kind: 1063, constructor: FileMetadata.fromMap, partialConstructor: PartialFileMetadata.fromMap);
    Model.register(kind: 3063, constructor: SoftwareAsset.fromMap, partialConstructor: PartialSoftwareAsset.fromMap);
    Model.register(kind: 1111, constructor: Comment.fromMap, partialConstructor: PartialComment.fromMap);
    Model.register(kind: 1222, constructor: VoiceMessage.fromMap, partialConstructor: PartialVoiceMessage.fromMap);
    Model.register(kind: 1244, constructor: VoiceMessageComment.fromMap, partialConstructor: PartialVoiceMessageComment.fromMap);
    Model.register(kind: 1984, constructor: Report.fromMap, partialConstructor: PartialReport.fromMap);
    Model.register(kind: 9734, constructor: ZapRequest.fromMap, partialConstructor: PartialZapRequest.fromMap);
    Model.register(kind: 9735, constructor: Zap.fromMap, partialConstructor: PartialZap.fromMap);
    Model.register(kind: 9802, constructor: Highlight.fromMap, partialConstructor: PartialHighlight.fromMap);

    // DVM
    Model.register(kind: 5312, constructor: VerifyReputationRequest.fromMap, partialConstructor: PartialVerifyReputationRequest.fromMap);
    Model.register(kind: 6312, constructor: VerifyReputationResponse.fromMap);
    Model.register(kind: 7000, constructor: DVMError.fromMap);

    // Replaceable
    Model.register(kind: 10222, constructor: Community.fromMap, partialConstructor: PartialCommunity.fromMap);

    // Ephemeral
    Model.register(kind: 24133, constructor: BunkerAuthorization.fromMap, partialConstructor: PartialBunkerAuthorization.fromMap);
    Model.register(kind: 24242, constructor: BlossomAuthorization.fromMap, partialConstructor: PartialBlossomAuthorization.fromMap);

    // Relay Lists
    Model.register(kind: 10002, constructor: SocialRelayList.fromMap, partialConstructor: PartialSocialRelayList.fromMap);
    Model.register(kind: 10067, constructor: AppCatalogRelayList.fromMap, partialConstructor: PartialAppCatalogRelayList.fromMap);

    // NIP-51: User Lists
    Model.register(kind: 10000, constructor: MuteList.fromMap, partialConstructor: PartialMuteList.fromMap);
    Model.register(kind: 10001, constructor: PinList.fromMap, partialConstructor: PartialPinList.fromMap);

    // Parameterized replaceable
    Model.register(kind: 30023, constructor: Article.fromMap, partialConstructor: PartialArticle.fromMap);
    Model.register(kind: 30063, constructor: Release.fromMap, partialConstructor: PartialRelease.fromMap);
    Model.register(kind: 30078, constructor: CustomData.fromMap, partialConstructor: PartialCustomData.fromMap);
    Model.register(kind: 30222, constructor: TargetedPublication.fromMap, partialConstructor: PartialTargetedPublication.fromMap);
    Model.register(kind: 30000, constructor: FollowSets.fromMap, partialConstructor: PartialFollowSets.fromMap);
    Model.register(kind: 30003, constructor: BookmarkSet.fromMap, partialConstructor: PartialBookmarkSet.fromMap);
    Model.register(kind: 30267, constructor: AppStack.fromMap, partialConstructor: PartialAppStack.fromMap);
    Model.register(kind: 32267, constructor: App.fromMap, partialConstructor: PartialApp.fromMap);

    // Calendar Events
    Model.register(kind: 31922, constructor: DateBasedCalendarEvent.fromMap, partialConstructor: PartialDateBasedCalendarEvent.fromMap);
    Model.register(kind: 31923, constructor: TimeBasedCalendarEvent.fromMap, partialConstructor: PartialTimeBasedCalendarEvent.fromMap);
    Model.register(kind: 31924, constructor: Calendar.fromMap, partialConstructor: PartialCalendar.fromMap);
    Model.register(kind: 31925, constructor: CalendarEventRSVP.fromMap, partialConstructor: PartialCalendarEventRSVP.fromMap);

    // NWC
    Model.register(kind: 13194, constructor: NwcInfo.fromMap, partialConstructor: PartialNwcInfo.fromMap);
    Model.register(kind: 23194, constructor: NwcRequest.fromMap, partialConstructor: PartialNwcRequest.fromMap);
    Model.register(kind: 23195, constructor: NwcResponse.fromMap, partialConstructor: PartialNwcResponse.fromMap);
    Model.register(kind: 23196, constructor: NwcNotification.fromMap, partialConstructor: PartialNwcNotification.fromMap);

    this.config = config;
    Model.initializeDummySigner(ref);
  }

  /// Resolve relay URLs from label with signed RelayList precedence.
  Future<Set<String>> resolveRelays(dynamic relays) async {
    if (relays == null) {
      return _resolveRelayIterable(config.defaultRelays['default'] ?? const {});
    }

    if (relays is Iterable && relays is! String) {
      return _resolveRelayIterable(relays);
    }

    final relayValue = relays.toString();

    if (relayValue.startsWith('ws://') || relayValue.startsWith('wss://')) {
      final normalized = normalizeRelayUrl(relayValue);
      return normalized != null ? {normalized} : {};
    }

    final kind = RelayList.labels[relayValue];
    if (kind != null) {
      return await _resolveByKind(kind, relayValue);
    }

    return _resolveRelayIterable(config.defaultRelays[relayValue] ?? const {});
  }

  Set<String> _resolveRelayIterable(Iterable relays) {
    final resolved = <String>{};
    for (final relay in relays) {
      final relayStr = relay.toString();
      if (relayStr.contains('://')) {
        final normalized = normalizeRelayUrl(relayStr);
        if (normalized != null) {
          resolved.add(normalized);
        }
      } else {
        final groupUrls = config.defaultRelays[relayStr];
        if (groupUrls != null) {
          for (final url in groupUrls) {
            final normalized = normalizeRelayUrl(url.toString());
            if (normalized != null) {
              resolved.add(normalized);
            }
          }
        }
      }
    }
    return resolved;
  }

  Future<Set<String>> _resolveByKind(int kind, String label) async {
    // Check for signed RelayList from active user
    final activePubkey = ref.read(Signer.activePubkeyProvider);
    if (activePubkey != null) {
      final results = querySync(RequestFilter(
        kinds: {kind},
        authors: {activePubkey},
      ).toRequest());
      if (results.isNotEmpty) {
        final relayList = results.first;
        if (relayList is RelayList && relayList.relays.isNotEmpty) {
          return relayList.relays;
        }
      }
    }
    return _resolveRelayIterable(config.defaultRelays[label] ?? const {});
  }

  // Abstract query/mutation methods

  List<E> querySync<E extends Model<dynamic>>(Request<E> req);

  Future<List<E>> query<E extends Model<dynamic>>(
    Request<E> req, {
    Source? source,
    String? subscriptionPrefix,
  });

  Future<bool> save(Set<Model<dynamic>> models);

  Future<PublishResponse> publish(
    Set<Model<dynamic>> models, {
    dynamic relays,
  });

  /// Helper: Check if a kind represents an encrypted event type.
  static bool isEncryptedKind(int kind) {
    return kind == 4 ||
        kind == 10000 ||
        kind == 10001 ||
        kind == 30003 ||
        kind == 30267 ||
        kind == 13194 ||
        kind == 23194 ||
        kind == 23195 ||
        kind == 23196;
  }

  Future<void> clear([Request? req]);
  Future<void> obliterate();
  Future<void> cancel(Request req);
  Future<void> closeSubscriptions({required dynamic relays});

  @override
  void dispose() {
    if (isInitialized) {
      super.dispose();
    }
  }
}

/// Normalize and sanitize a single relay URL string.
String? normalizeRelayUrl(String url) {
  if (url.contains(',')) return null;

  try {
    final uri = Uri.parse(url.trim());
    if (uri.host.isEmpty) return null;

    final scheme =
        (uri.scheme == 'ws' || uri.scheme == 'wss') ? uri.scheme : 'wss';

    int? port = uri.hasPort ? uri.port : null;
    if ((scheme == 'ws' && (port == null || port == 80)) ||
        (scheme == 'wss' && (port == null || port == 443))) {
      port = null;
    }

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
    return null;
  }
}

/// Provider for the storage notifier.
final storageNotifierProvider =
    StateNotifierProvider<StorageNotifier, StorageState>(
  (ref) => throw UnimplementedError(
      'storageNotifierProvider must be overridden. Use DummyStorageNotifier for testing.'),
);

extension RefExt on Ref {
  StorageNotifier get storage => read(storageNotifierProvider.notifier);
}

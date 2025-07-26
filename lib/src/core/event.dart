part of models;

/// Base class for all Nostr events, both mutable and immutable.
///
/// Provides common functionality for event handling, tag manipulation,
/// and data access patterns used across all event types.
sealed class EventBase<E extends Model<E>> {
  EventBase([Map<String, dynamic>? map])
    : content = map?['content'] ?? '',
      createdAt = (map?['created_at'] as int?)?.toDate() ?? DateTime.now(),
      tags = [
        for (final tag in map?['tags'] ?? [])
          if (tag is Iterable && tag.length > 1)
            [for (final e in tag) e.toString()],
      ] {
    if (map != null && map['kind'] != kind) {
      throw Exception(
        'Kind mismatch! Incoming JSON kind (${map['kind']}) is not of the kind of type $E ($kind)',
      );
    }
  }

  /// The Nostr event kind number.
  final int kind = Model._kindFor<E>();

  /// When this event was created.
  DateTime createdAt;

  /// The content/body of this event.
  String content;

  /// Tags associated with this event.
  ///
  /// Tags are arrays of strings where the first element is the tag name
  /// and subsequent elements are the tag values.
  List<List<String>> tags;

  Map<String, dynamic> toMap();

  // Read tag utilities

  /// Get all tags with the specified key as a set.
  Set<List<String>> getTagSet(String key) =>
      tags.where((e) => e[0] == key).toSet();

  /// Check if this event contains any tags with the specified key.
  bool containsTag(String key) => tags.any((t) => t[0] == key);

  /// Get the first tag with the specified key, or null if none found.
  List<String>? getFirstTag(String key) {
    return tags.firstWhereOrNull((t) => t[0] == key);
  }

  /// Get the value (second element) of the first tag with the specified key.
  String? getFirstTagValue(String key) {
    return getFirstTag(key)?[1];
  }

  /// Get all tag values for the specified key as a set.
  Set<String> getTagSetValues(String key) =>
      getTagSet(key).map((e) => e[1]).toSet();
}

/// A finalized (signed) Nostr event that cannot be modified.
///
/// This represents a complete, immutable Nostr event with a signature
/// and event ID. All [Model] instances wrap an [ImmutableEvent].
/// ```
final class ImmutableEvent<E extends Model<E>> extends EventBase<E> {
  /// The unique event ID (hex-encoded SHA256 hash).
  final String id;

  @override
  DateTime get createdAt;
  final String pubkey;
  @override
  String get content;
  @override
  List<List<String>> get tags;
  // Signature is nullable as it may be removed as optimization
  final String? signature;

  /// Metadata is used to hold additional arbitrary data/metadata,
  /// useful to parse once in-event data that requires expensive decoding
  final Map<String, dynamic> metadata;

  /// Keep track of which relays this event was fetched from
  final Set<String> relays;

  ImmutableEvent(Map<String, dynamic> map)
    : id = map['id'],
      pubkey = map['pubkey'],
      signature = map['sig'],
      metadata = Map<String, dynamic>.from(map['metadata'] ?? {}),
      relays = <String>{...?map['relays']},
      super(map);

  /// Addressable event ID to use in tags
  String get addressableId {
    return switch (this) {
      ImmutableParameterizableReplaceableEvent(:final identifier) =>
        '$kind:$pubkey:$identifier',
      ImmutableReplaceableEvent() => '$kind:$pubkey:',
      ImmutableEvent() => id,
    };
  }

  String get addressableIdTagLetter =>
      this is ImmutableReplaceableEvent ? 'a' : 'e';

  Map<String, Set<String>> get addressableIdTagMap => {
    '#$addressableIdTagLetter': {addressableId},
  };

  /// NIP-19
  String get shareableId {
    switch (this) {
      case ImmutableParameterizableReplaceableEvent(:final identifier):
        // naddr
        return Utils.encodeShareableIdentifier(
          AddressInput(identifier: identifier, author: pubkey, kind: kind),
        );
      default:
        // nprofile
        if (kind == 0) {
          return Utils.encodeShareableIdentifier(ProfileInput(pubkey: pubkey));
        }
        // nevent
        return Utils.encodeShareableIdentifier(EventInput(eventId: id));
    }
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.toSeconds(),
      'pubkey': pubkey,
      'kind': kind,
      'tags': tags,
      'sig': signature,
    };
  }
}

/// A finalized (signed) nostr replaceable event
final class ImmutableReplaceableEvent<E extends Model<E>>
    extends ImmutableEvent<E> {
  ImmutableReplaceableEvent(super.map);
}

/// A finalized (signed) nostr parameterized replaceable event
final class ImmutableParameterizableReplaceableEvent<E extends Model<E>>
    extends ImmutableReplaceableEvent<E> {
  ImmutableParameterizableReplaceableEvent(super.map);

  String get identifier => getFirstTagValue('d')!;
}

/// A partial, mutable, unsigned nostr event
final class PartialEvent<E extends Model<E>> extends EventBase<E> {
  PartialEvent([Map<String, dynamic>? map]) : super(map);

  String? pubkey;

  String? get id => pubkey != null ? Utils.getEventId(this, pubkey!) : null;

  // Metadata
  Map<String, dynamic> metadata = {};

  @override
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (pubkey != null) 'pubkey': pubkey,
      'content': content,
      'created_at': createdAt.toSeconds(),
      'kind': kind,
      'tags': tags,
    };
  }

  /// Addressable event ID to use in tags
  String addressableIdFor(String pubkey, {String? identifier}) {
    return '$kind:$pubkey:${identifier ?? getFirstTagValue('d')}';
  }

  String? get identifier => getFirstTagValue('d');
  set identifier(String? value) => setTagValue('d', value);

  // Tag mutation utilities

  void addTagValue(String key, String? value) {
    if (value != null) {
      tags.add([key, value]);
    }
  }

  void addTagValues(String key, Set<String> values) {
    for (final value in values) {
      tags.add([key, value]);
    }
  }

  void removeTagWithValue(String key, [String? value]) {
    if (value != null) {
      tags.removeWhere((t) => t[1] == value);
    } else {
      tags.removeWhere((t) => t.first == key);
    }
  }

  void setTagValue(String key, String? value) {
    if (value != null) {
      removeTagWithValue(key);
      addTagValue(key, value);
    }
  }

  void setTagValues(String key, Set<String> values) {
    removeTag(key);
    addTagValues(key, values);
  }

  void addTag(String key, List<String> tag) {
    tags.add([key, ...tag]);
  }

  void removeTag(String key) {
    tags.removeWhere((t) => t[0] == key);
  }

  void setTag(String key, List<String> tag) {
    removeTag(key);
    addTag(key, tag);
  }
}

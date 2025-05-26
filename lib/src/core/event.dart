part of models;

sealed class EventBase<E extends Model<E>> {
  final int kind = Model._kindFor<E>();
  DateTime get createdAt;
  String get content;
  List<List<String>> get tags;

  Map<String, dynamic> toMap();

  // Read tag utilities

  Set<List<String>> getTagSet(String key) =>
      tags.where((e) => e[0] == key).toSet();

  bool containsTag(String key) => tags.any((t) => t[0] == key);

  List<String>? getFirstTag(String key) {
    return tags.firstWhereOrNull((t) => t[0] == key);
  }

  String? getFirstTagValue(String key) {
    return getFirstTag(key)?[1];
  }

  Set<String> getTagSetValues(String key) =>
      getTagSet(key).map((e) => e[1]).toSet();
}

/// A finalized (signed) nostr event
final class ImmutableEvent<E extends Model<E>> extends EventBase<E> {
  final String id;
  @override
  final DateTime createdAt;
  final String pubkey;
  @override
  final String content;
  @override
  final List<List<String>> tags;
  // Signature is nullable as it may be removed as optimization
  final String? signature;

  /// Metadata is used to hold additional arbitrary data/metadata,
  /// useful to parse once in-event data that requires expensive decoding
  final Map<String, dynamic> metadata;

  /// Keep track of which relays this event was fetched from
  final Set<String> relays;

  ImmutableEvent(Map<String, dynamic> map)
      : id = map['id'],
        content = map['content'],
        pubkey = map['pubkey'],
        createdAt = (map['created_at'] as int).toDate(),
        tags = [
          for (final tag in map['tags'])
            if (tag is Iterable && tag.length > 1)
              [for (final e in tag) e.toString()]
        ],
        signature = map['sig'],
        metadata = Map<String, dynamic>.from(map['metadata'] ?? {}),
        relays = <String>{...?map['relays']} {
    if (map['kind'] != kind) {
      throw Exception(
          'Kind mismatch! Incoming JSON kind (${map['kind']}) is not of the kind of type $E ($kind)');
    }
  }

  /// Addressable event ID to use in tags
  String get addressableId {
    return switch (this) {
      ImmutableParameterizableReplaceableEvent(:final identifier) =>
        '$kind:$pubkey:$identifier',
      ImmutableReplaceableEvent() => '$kind:$pubkey:',
      ImmutableEvent() => id
    };
  }

  String get addressableIdTagLetter =>
      this is ImmutableReplaceableEvent ? 'a' : 'e';

  Map<String, Set<String>> get addressableIdTagMap => {
        '#$addressableIdTagLetter': {addressableId}
      };

  /// NIP-19
  String get shareableId {
    switch (this) {
      case ImmutableParameterizableReplaceableEvent(:final identifier):
        // naddr
        return encodeShareableIdentifiers(
            prefix: 'naddr',
            special: identifier,
            relays: null,
            author: pubkey,
            kind: kind);
      default:
        // nprofile
        if (kind == 0) {
          return encodeShareableIdentifiers(
              prefix: 'nprofile',
              special: pubkey,
              relays: null,
              author: null,
              kind: null);
        }
        // nevent
        return encodeShareableIdentifiers(
            prefix: 'nevent',
            special: id,
            relays: null,
            author: null,
            kind: null);
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
  // No ID, pubkey or signature
  // Kind is inherited
  @override
  String content = '';
  @override
  DateTime createdAt = DateTime.now();
  @override
  List<List<String>> tags = [];

  // Metadata
  Map<String, dynamic> metadata = {};

  @override
  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'created_at': createdAt.toSeconds(),
      'kind': kind,
      'tags': tags,
    };
  }

  // TODO: This should be improved and look like its immutable counterpart
  /// Addressable event ID to use in tags
  String addressableIdFor(String pubkey, {String? identifier}) {
    return '$kind:$pubkey:${identifier ?? getFirstTagValue('d')}';
  }

  String? get identifier => getFirstTagValue('d');

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

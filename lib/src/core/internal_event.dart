part of models;

sealed class InternalEvent<E extends Event<E>> {
  final int kind = Event.getKindFor<E>();
  DateTime get createdAt;
  String get content;
  List<List<String>> get tags;

  String? getFirstTagValue(String key) {
    return getFirstTag(key)?[1];
  }

  List<String>? getFirstTag(String key) {
    return tags.firstWhereOrNull((t) => t[0] == key);
  }

  Set<String> getTagSetValues(String key) =>
      getTagSet(key).map((e) => e[1]).toSet();

  Set<List<String>> getTagSet(String key) =>
      tags.where((e) => e[0] == key).toSet();

  bool containsTag(String key) => tags.any((t) => t[0] == key);
}

final class ImmutableInternalEvent<E extends Event<E>>
    extends InternalEvent<E> {
  final String id;
  @override
  final DateTime createdAt;
  final String pubkey;
  @override
  final String content;
  @override
  final List<List<String>> tags;
  final Set<String> relays;
  // Signature is nullable as it may be removed as optimization
  final String? signature;
  // Metadata
  final Map<String, dynamic> metadata;

  ImmutableInternalEvent(Map<String, dynamic> map)
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

  String get addressableId {
    return switch (this) {
      ImmutableParameterizableReplaceableInternalEvent(:final identifier) =>
        '$kind:$pubkey:$identifier',
      ImmutableReplaceableInternalEvent() => '$kind:$pubkey:',
      ImmutableInternalEvent() => id
    };
  }

  String get shareableId {
    switch (this) {
      case ImmutableParameterizableReplaceableInternalEvent(:final identifier):
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

  String get addressableIdTagLetter =>
      this is ImmutableReplaceableInternalEvent ? 'a' : 'e';

  Map<String, Set<String>> get addressableIdTagMap => {
        '#$addressableIdTagLetter': {id}
      };
}

final class ImmutableReplaceableInternalEvent<E extends Event<E>>
    extends ImmutableInternalEvent<E> {
  ImmutableReplaceableInternalEvent(super.map);
}

final class ImmutableParameterizableReplaceableInternalEvent<E extends Event<E>>
    extends ImmutableReplaceableInternalEvent<E> {
  ImmutableParameterizableReplaceableInternalEvent(super.map);

  String get identifier => getFirstTagValue('d')!;
}

final class PartialInternalEvent<E extends Event<E>> extends InternalEvent<E> {
  // No ID, pubkey or signature
  // Kind is inherited
  @override
  String content = '';
  @override
  DateTime createdAt = DateTime.now();
  @override
  List<List<String>> tags = [];

  void addTagValue(String key, String? value) {
    if (value != null) {
      tags.add([key, value]);
    }
  }

  void addTagValues(String key, List<String> values) {
    for (final value in values) {
      tags.add([key, value]);
    }
  }

  void addTag(String key, List<String> tag) {
    tags.add([key, ...tag]);
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
}

import 'package:collection/collection.dart';
import 'package:models/models.dart';
import 'package:models/src/core/encoding.dart';
import 'package:models/src/core/extensions.dart';

sealed class InternalEvent<E extends Event<E>> {
  final int kind = Event.types[E.toString()]!.kind;
  DateTime get createdAt;
  String get content;
  Map<String, Set<TagValue>> get tags;

  String? getFirstTagValue(String key) {
    return getFirstTag(key)?.value;
  }

  TagValue? getFirstTag(String key) {
    return tags[key]?.firstOrNull;
  }

  Set<String> getTagSetValues(String key) =>
      getTagSet(key).map((e) => e.value).toSet();

  Set<TagValue> getTagSet(String key) => tags[key]?.toSet() ?? {};

  bool containsTag(String key) => tags.containsKey(key);
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
  final Map<String, Set<TagValue>> tags;
  // Signature is nullable as it may be removed as optimization
  final String? signature;

  ImmutableInternalEvent(Map<String, dynamic> map)
      : id = map['id'],
        content = map['content'],
        pubkey = map['pubkey'],
        createdAt = (map['created_at'] as int).toDate(),
        tags = TagValue.deserialize(map['tags']),
        signature = map['sig'];

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

  String get addressableId {
    return switch (this) {
      ImmutableParameterizableReplaceableInternalEvent(:final identifier) =>
        '$kind:$pubkey:$identifier',
      ImmutableReplaceableInternalEvent() => '$kind:$pubkey:',
      ImmutableInternalEvent() => id
    };
  }

  Map<String, Set<String>> get addressableIdTagMap => {
        this is ImmutableReplaceableInternalEvent ? '#a' : '#e': {addressableId}
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
  Map<String, Set<TagValue>> tags = {};

  void addTagValue(String key, String? value) {
    if (value != null) {
      tags[key] ??= {};
      tags[key]!.add(TagValue([value]));
    }
  }

  void addTag(String key, TagValue tag) {
    tags[key] ??= {};
    tags[key]!.add(tag);
  }

  void removeTagWithValue(String key, [String? value]) {
    if (value != null) {
      tags[key]?.removeWhere((t) => t.value == value);
    } else {
      tags.remove(key);
    }
  }

  void setTagValue(String key, String? value) {
    if (value != null) {
      removeTagWithValue(key);
      addTagValue(key, value);
    }
  }
}

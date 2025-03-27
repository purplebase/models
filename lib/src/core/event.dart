import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:models/src/core/utils.dart';
import 'package:riverpod/riverpod.dart';

mixin EventBase<E extends Event<E>> {
  InternalEvent get internal;
  Map<String, dynamic> toMap();
}

sealed class Event<E extends Event<E>>
    with EquatableMixin
    implements EventBase<E> {
  @override
  final ImmutableInternalEvent internal;
  final Ref ref;

  late final BelongsTo<Profile> author;
  late final HasMany<Reaction> reactions;
  late final HasMany<Zap> zaps;

  Event._internal(this.ref, this.internal);

  Event.fromMap(Map<String, dynamic> map, this.ref)
      : internal = ImmutableInternalEvent<E>(map) {
    if (map['kind'] != internal.kind) {
      throw Exception(
          'Kind mismatch! Incoming JSON kind (${map['kind']}) is not of the kind of type $E (${internal.kind})');
    }

    final kindCheck = switch (internal.kind) {
      >= 10000 && < 20000 || 0 || 3 => this is ReplaceableEvent,
      >= 20000 && < 30000 => this is EphemeralEvent,
      >= 30000 && < 40000 => this is ParameterizableReplaceableEvent,
      _ => this is RegularEvent,
    };
    if (!kindCheck) {
      throw Exception(
          'Kind ${internal.kind} does not match the type of event: regular, replaceable, etc. Check the model definition inherits the right one.');
    }

    // General relationships
    author =
        BelongsTo(ref, RequestFilter(kinds: {0}, authors: {internal.pubkey}));

    reactions = HasMany<Reaction>(
        ref, RequestFilter(kinds: {7}, tags: internal.addressableIdTagMap));

    zaps = HasMany<Zap>(
        ref, RequestFilter(kinds: {9735}, tags: internal.addressableIdTagMap));
  }

  String get id => internal.addressableId;

  DateTime get createdAt => internal.createdAt;

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': internal.id,
      'content': internal.content,
      'created_at': internal.createdAt.toSeconds(),
      'pubkey': internal.pubkey,
      'kind': internal.kind,
      'tags': TagValue.serialize(internal.tags),
      'sig': internal.signature,
    };
  }

  @override
  List<Object?> get props => [internal.id];

  @override
  String toString() {
    return toMap().toString();
  }

  // Registerable mappings
  static final Map<String, ({int kind, EventConstructor constructor})> types = {
    'Profile': (kind: 0, constructor: Profile.fromMap),
    'Note': (kind: 1, constructor: Note.fromMap),
    'DirectMessage': (kind: 4, constructor: DirectMessage.fromMap),
    'ChatMessage': (kind: 9, constructor: ChatMessage.fromMap),
    'Reaction': (kind: 7, constructor: Reaction.fromMap),
    'FileMetadata': (kind: 1063, constructor: FileMetadata.fromMap),
    'ZapRequest': (kind: 9734, constructor: ZapRequest.fromMap),
    'Zap': (kind: 9735, constructor: Zap.fromMap),
    'Article': (kind: 30023, constructor: Article.fromMap),
    'Release': (kind: 30063, constructor: Release.fromMap),
    'AppCurationSet': (kind: 30267, constructor: AppCurationSet.fromMap),
    'App': (kind: 32267, constructor: App.fromMap)
  };

  static EventConstructor<E>? getConstructor<E extends Event<E>>() {
    final constructor =
        types[E.toString()]?.constructor as EventConstructor<E>?;
    if (constructor == null) {
      throw Exception('''
Could not find the constructor for $E. Did you forget to register the type?

You can do so by calling: Event.types['$E'] = (kind, $E.fromMap);
''');
    }
    return constructor;
  }
}

mixin PartialEventBase<E extends Event<E>> implements EventBase<E> {
  @override
  PartialInternalEvent get internal;

  void linkEvent(Event e,
      {String? relayUrl, EventMarker? marker, String? pubkey}) {
    internal.addTag(
        'e',
        EventTagValue(e.id,
            relayUrl: relayUrl, marker: marker, pubkey: pubkey));
  }

  void unlinkEvent(Event e) => internal.removeTagWithValue('e', e.internal.id);

  void linkProfile(Profile p) => internal.setTagValue('p', p.pubkey);
  void unlinkProfile(Profile u) => internal.removeTagWithValue('p', u.pubkey);
}

sealed class PartialEvent<E extends Event<E>>
    with Signable<E>, PartialEventBase<E> {
  @override
  final PartialInternalEvent internal = PartialInternalEvent<E>();

  @override
  Map<String, dynamic> toMap() {
    return {
      'content': internal.content,
      'created_at': internal.createdAt.toSeconds(),
      'kind': internal.kind,
      'tags': TagValue.serialize(internal.tags),
    };
  }

  @override
  String toString() {
    return jsonEncode(toMap());
  }
}

// Internal events

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

  String get nevent => bech32Encode('nevent', id);

  String get addressableId => switch (this) {
        ImmutableReplaceableInternalEvent() =>
          (this as ImmutableReplaceableInternalEvent)
              .getReplaceableEventLink()
              .formatted,
        _ => id,
      };

  Map<String, Set<String>> get addressableIdTagMap => switch (this) {
        ImmutableReplaceableInternalEvent() => {
            '#a': {
              (this as ImmutableReplaceableInternalEvent)
                  .getReplaceableEventLink()
                  .formatted
            }
          },
        _ => {
            '#e': {id}
          },
      };
}

final class ImmutableReplaceableInternalEvent<E extends Event<E>>
    extends ImmutableInternalEvent<E> {
  ImmutableReplaceableInternalEvent(super.map);

  ReplaceableEventLink getReplaceableEventLink({String? pubkey}) =>
      (kind, pubkey ?? this.pubkey, null);
}

final class ImmutableParameterizableReplaceableInternalEvent<E extends Event<E>>
    extends ImmutableReplaceableInternalEvent<E> {
  ImmutableParameterizableReplaceableInternalEvent(super.map);

  String get identifier => getFirstTagValue('d')!;

  @override
  ReplaceableEventLink getReplaceableEventLink({String? pubkey}) =>
      (kind, pubkey ?? this.pubkey, identifier);
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

// Event types

// Create an empty mixin in order to use the = class definitions
mixin _EmptyMixin {}

abstract class RegularEvent<E extends Event<E>> = Event<E> with _EmptyMixin;
abstract class RegularPartialEvent<E extends Event<E>> = PartialEvent<E>
    with _EmptyMixin;

abstract class EphemeralEvent<E extends Event<E>> = Event<E> with _EmptyMixin;
abstract class EphemeralPartialEvent<E extends Event<E>> = PartialEvent<E>
    with _EmptyMixin;

abstract class ReplaceableEvent<E extends Event<E>> extends Event<E> {
  @override
  ImmutableReplaceableInternalEvent<E> get internal =>
      super.internal as ImmutableReplaceableInternalEvent<E>;

  ReplaceableEvent.fromMap(Map<String, dynamic> map, Ref ref)
      : this._internal(ref, ImmutableReplaceableInternalEvent<E>(map));

  ReplaceableEvent._internal(
      Ref ref, ImmutableReplaceableInternalEvent internal)
      : super._internal(ref, internal);

  @override
  List<Object?> get props => [id];
}

abstract class ReplaceablePartialEvent<E extends Event<E>> = PartialEvent<E>
    with _EmptyMixin;

//

abstract class ParameterizableReplaceableEvent<E extends Event<E>>
    extends ReplaceableEvent<E> {
  @override
  ImmutableParameterizableReplaceableInternalEvent<E> get internal =>
      super.internal as ImmutableParameterizableReplaceableInternalEvent<E>;

  ParameterizableReplaceableEvent.fromMap(Map<String, dynamic> map, Ref ref)
      : super._internal(
            ref, ImmutableParameterizableReplaceableInternalEvent<E>(map)) {
    if (!internal.containsTag('d')) {
      throw Exception('Event must contain a `d` tag');
    }
  }
}

abstract class ParameterizableReplaceablePartialEvent<E extends Event<E>>
    extends ReplaceablePartialEvent<E> {
  String? get identifier => internal.getFirstTagValue('d');
  set identifier(String? value) => internal.setTagValue('d', value);
}

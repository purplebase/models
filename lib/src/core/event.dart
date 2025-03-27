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

  Event.fromMap(Map<String, dynamic> map, this.ref)
      : internal = ImmutableInternalEvent<E>(
            id: map['id'],
            content: map['content'],
            pubkey: map['pubkey'],
            createdAt: (map['created_at'] as int).toDate(),
            tags: deserializeTags(map['tags']),
            signature: map['sig']) {
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
        ref,
        RequestFilter(kinds: {
          7
        }, tags: {
          // TODO: Does this work for replaceable events?
          '#e': {internal.id}
        }));

    zaps = HasMany<Zap>(
        ref,
        RequestFilter(kinds: {
          9735
        }, tags: {
          // TODO: Does this work for replaceable events?
          '#e': {internal.id}
        }));
  }

  DateTime get createdAt => internal.createdAt;

  static Map<String, Set<TagValue>> deserializeTags(Iterable originalTags) {
    final tagList = [for (final t in originalTags) List.from(t).cast<String>()];
    return tagList.fold(<String, Set<TagValue>>{}, (acc, e) {
      if (e.length >= 2) {
        final [name, ...rest] = e;
        acc[name] ??= {};
        if (name == 'e') {
          acc[name]!.add(EventTagValue(rest.first,
              relayUrl: rest[1],
              marker:
                  rest.length > 2 ? EventMarker.fromString(rest[2]) : null));
        } else {
          acc[name]!.add(TagValue(rest));
        }
      }
      return acc;
    });
  }

  static List<List<String>> serializeTags(Map<String, Set<TagValue>> tags) {
    return [
      for (final e in tags.entries)
        for (final t in e.value) [e.key, ...t.values]
    ];
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': internal.id,
      'content': internal.content,
      'created_at': internal.createdAt.toSeconds(),
      'pubkey': internal.pubkey,
      'kind': internal.kind,
      'tags': serializeTags(internal.tags),
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
    switch (e) {
      case ReplaceableEvent():
        internal.addTag(
            'a',
            EventTagValue(e.getReplaceableEventLink().formatted,
                relayUrl: relayUrl, marker: marker, pubkey: pubkey));
      case _:
        internal.addTag(
            'e',
            EventTagValue(e.internal.id,
                relayUrl: relayUrl, marker: marker, pubkey: pubkey));
    }
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
      'tags': Event.serializeTags(internal.tags),
    };
  }

  @override
  String toString() {
    return jsonEncode(toMap());
  }
}

final class TagValue with EquatableMixin {
  final List<String> values;
  TagValue(this.values) {
    if (values.isEmpty) throw 'empty tag';
  }
  String get value => values.first;

  @override
  List<Object?> get props => values;

  @override
  String toString() {
    return values.toString();
  }
}

final class EventTagValue extends TagValue {
  final String? relayUrl;
  final EventMarker? marker;
  final String? pubkey;
  EventTagValue(String value, {this.relayUrl, this.marker, this.pubkey})
      : super([
          value,
          relayUrl ?? "",
          if (marker != null) marker.name,
          if (pubkey != null) pubkey
        ]);
}

enum EventMarker {
  reply,
  root,
  mention;

  static fromString(String value) {
    for (final element in EventMarker.values) {
      if (element.name.toLowerCase() == value.toLowerCase()) {
        return element;
      }
    }
    return null;
  }
}

// Internal events

sealed class InternalEvent<E extends Event<E>> {
  final int kind = Event.types[E.toString()]!.kind;
  DateTime get createdAt;
  String get content;
  Map<String, Set<TagValue>> get tags;

  // TODO: Implement nevent
  String get nevent => 'nevent123';

  Set<String> get linkedEventIds => getTagSetValues('e');
  Set<ReplaceableEventLink> get linkedReplaceableEventIds {
    return getTagSetValues('a').map((e) => e.toReplaceableLink()).toSet();
  }

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
  ImmutableInternalEvent(
      {required this.id,
      required this.createdAt,
      required this.pubkey,
      required this.tags,
      required this.content,
      required this.signature});
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

// Use an empty mixin in order to use the = class definitions
mixin _EmptyMixin {}

abstract class RegularEvent<E extends Event<E>> = Event<E> with _EmptyMixin;
abstract class RegularPartialEvent<E extends Event<E>> = PartialEvent<E>
    with _EmptyMixin;

abstract class EphemeralEvent<E extends Event<E>> = Event<E> with _EmptyMixin;
abstract class EphemeralPartialEvent<E extends Event<E>> = PartialEvent<E>
    with _EmptyMixin;

abstract class ReplaceableEvent<E extends Event<E>> extends Event<E> {
  ReplaceableEvent.fromMap(super.map, super.ref) : super.fromMap();

  ReplaceableEventLink getReplaceableEventLink({String? pubkey}) =>
      (internal.kind, pubkey ?? internal.pubkey, null);

  @override
  List<Object?> get props => [getReplaceableEventLink().formatted];
}

abstract class ReplaceablePartialEvent<E extends Event<E>> = PartialEvent<E>
    with _EmptyMixin;

// TODO: Rethink this mixin
mixin IdentifierMixin {
  String? get identifier;
}

abstract class ParameterizableReplaceableEvent<E extends Event<E>>
    extends ReplaceableEvent<E> implements IdentifierMixin {
  ParameterizableReplaceableEvent.fromMap(super.map, super.ref)
      : super.fromMap() {
    if (!internal.containsTag('d')) {
      throw Exception('Event must contain a `d` tag');
    }
  }

  @override
  String get identifier => internal.getFirstTagValue('d')!;

  @override
  ReplaceableEventLink getReplaceableEventLink({String? pubkey}) =>
      (internal.kind, pubkey ?? internal.pubkey, identifier);
}

abstract class ParameterizableReplaceablePartialEvent<E extends Event<E>>
    extends ReplaceablePartialEvent<E> implements IdentifierMixin {
  @override
  String? get identifier => internal.getFirstTagValue('d');
  set identifier(String? value) => internal.setTagValue('d', value);
}

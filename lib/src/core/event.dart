import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:models/src/models/app.dart';
import 'package:models/src/models/direct_message.dart';
import 'package:models/src/models/file_metadata.dart';
import 'package:models/src/models/lists.dart';
import 'package:models/src/models/note.dart';
import 'package:models/src/models/profile.dart';
import 'package:models/src/models/reaction.dart';
import 'package:models/src/models/release.dart';
import 'package:models/src/models/zap_receipt.dart';
import 'package:models/src/models/zap_request.dart';
import 'package:models/src/core/signer.dart';
import 'package:models/src/core/utils.dart';
import 'package:riverpod/riverpod.dart';

mixin EventBase<E extends Event<E>> {
  // TODO: Make event private and access via EventBase.getFor(this)
  InternalEvent get event;
  Map<String, dynamic> toMap();
}

sealed class Event<E extends Event<E>>
    with EquatableMixin
    implements EventBase<E> {
  @override
  final ImmutableInternalEvent event;
  final Ref ref;

  Event.fromJson(Map<String, dynamic> map, this.ref)
      : event = ImmutableInternalEvent<E>(
            id: map['id'],
            content: map['content'],
            pubkey: map['pubkey'],
            createdAt: (map['created_at'] as int).toDate(),
            tags: deserializeTags(map['tags']),
            signature: map['sig']) {
    if (map['kind'] != event.kind) {
      throw Exception(
          'Kind mismatch! Incoming JSON kind (${map['kind']}) is not of the kind of type $E (${event.kind})');
    }

    final kindCheck = switch (event.kind) {
      // TODO: Check NIP-01 again, something about n < 45
      >= 10000 && < 20000 || 0 || 3 => this is ReplaceableEvent,
      >= 20000 && < 30000 => this is EphemeralEvent,
      >= 30000 && < 40000 => this is ParameterizableReplaceableEvent,
      _ => this is RegularEvent,
    };
    if (!kindCheck) {
      throw Exception(
          'Kind ${event.kind} does not match the type of event: regular, replaceable, etc. Check the model definition inherits the right one.');
    }
  }

  static Map<String, Set<TagValue>> deserializeTags(Iterable originalTags) {
    final tagList = [
      for (final t in originalTags)
        List.from(t).map((e) => e.toString()).toList()
    ];
    return tagList.fold(<String, Set<TagValue>>{}, (acc, e) {
      if (e.length >= 2) {
        final [name, ...rest] = e;
        if (e.length >= 2) {
          acc[name] ??= {};
          if (name == 'e') {
            acc[name]!.add(EventTagValue(rest.first,
                relayUrl: rest[1], marker: EventMarker.fromString(rest[2])));
          } else {
            acc[name]!.add(TagValue(rest));
          }
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
      'id': event.id,
      'content': event.content,
      'created_at': event.createdAt.toSeconds(),
      'pubkey': event.pubkey,
      'kind': event.kind,
      'tags': serializeTags(event.tags),
      'sig': event.signature,
    };
  }

  @override
  List<Object?> get props => [event.id];

  @override
  String toString() {
    return toMap().toString();
  }

  // Registerable mappings
  static final Map<String, ({int kind, EventConstructor constructor})> types = {
    'Profile': (kind: 0, constructor: Profile.fromJson),
    'Note': (kind: 1, constructor: Note.fromJson),
    'Reaction': (kind: 7, constructor: Reaction.fromJson),
    'DirectMessage': (kind: 4, constructor: DirectMessage.fromJson),
    'FileMetadata': (kind: 1063, constructor: FileMetadata.fromJson),
    'ZapRequest': (kind: 9734, constructor: ZapRequest.fromJson),
    'ZapReceipt': (kind: 9735, constructor: ZapReceipt.fromJson),
    'Release': (kind: 30063, constructor: Release.fromJson),
    'AppCurationSet': (kind: 30267, constructor: AppCurationSet.fromJson),
    'App': (kind: 32267, constructor: App.fromJson)
  };

  static EventConstructor<E>? getConstructor<E extends Event<E>>() {
    final constructor =
        types[E.toString()]?.constructor as EventConstructor<E>?;
    if (constructor == null) {
      throw Exception('''
Could not find the constructor for $E. Did you forget to register the type?

You can do so by calling: Event.types['$E'] = (kind, $E.fromJson);
''');
    }
    return constructor;
  }
}

mixin PartialEventBase<E extends Event<E>> implements EventBase<E> {
  @override
  PartialInternalEvent get event;

  void linkEvent(Event e,
      {String? relayUrl, EventMarker? marker, String? pubkey}) {
    switch (e) {
      case ReplaceableEvent():
        event.addTag(
            'a',
            EventTagValue(e.getReplaceableEventLink().formatted,
                relayUrl: relayUrl, marker: marker, pubkey: pubkey));
      case _:
        event.addTag(
            'e',
            EventTagValue(e.event.id,
                relayUrl: relayUrl, marker: marker, pubkey: pubkey));
    }
  }

  void unlinkEvent(Event e) => event.removeTagWithValue('e', e.event.id);

  void linkProfile(Profile p) => event.setTagValue('p', p.pubkey);
  void unlinkProfile(Profile u) => event.removeTagWithValue('p', u.pubkey);
}

sealed class PartialEvent<E extends Event<E>>
    with Signable<E>, PartialEventBase<E> {
  @override
  final PartialInternalEvent event = PartialInternalEvent<E>();

  @override
  Map<String, dynamic> toMap() {
    return {
      'content': event.content,
      'created_at': event.createdAt.toSeconds(),
      'kind': event.kind,
      'tags': Event.serializeTags(event.tags),
    };
  }

  @override
  String toString() {
    return jsonEncode(toMap());
  }
}

class TagValue {
  final List<String> values;
  const TagValue(this.values);
  String get value => values.first;
  @override
  String toString() {
    return values.toString();
  }
}

class EventTagValue extends TagValue {
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

  Set<String> get linkedEvents => getTagSet('e');
  Set<ReplaceableEventLink> get linkedReplaceableEvents {
    return getTagSet('a').map((e) => e.toReplaceableLink()).toSet();
  }

  String? getFirstTagValue(String key) {
    return tags[key]?.firstOrNull?.values.firstOrNull;
  }

  TagValue? getFirstTag(String key) {
    return tags[key]?.firstOrNull;
  }

  Set<String> getTagSet(String key) =>
      tags[key]?.map((t) => t.value).toSet() ?? {};

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
  ReplaceableEvent.fromJson(super.map, super.ref) : super.fromJson();

  ReplaceableEventLink getReplaceableEventLink({String? pubkey}) =>
      (event.kind, pubkey ?? event.pubkey, null);

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
  ParameterizableReplaceableEvent.fromJson(super.map, super.ref)
      : super.fromJson() {
    if (!event.containsTag('d')) {
      throw Exception('Event must contain a `d` tag');
    }
  }

  @override
  String get identifier => event.getFirstTagValue('d')!;

  @override
  ReplaceableEventLink getReplaceableEventLink({String? pubkey}) =>
      (event.kind, pubkey ?? event.pubkey, identifier);
}

abstract class ParameterizableReplaceablePartialEvent<E extends Event<E>>
    extends ReplaceablePartialEvent<E> implements IdentifierMixin {
  @override
  String? get identifier => event.getFirstTagValue('d');
  set identifier(String? value) => event.setTagValue('d', value);
}

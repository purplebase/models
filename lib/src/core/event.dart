import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:models/src/models/app.dart';
import 'package:models/src/models/direct_message.dart';
import 'package:models/src/models/file_metadata.dart';
import 'package:models/src/models/lists.dart';
import 'package:models/src/models/note.dart';
import 'package:models/src/models/profile.dart';
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
            tags: [for (final t in map['tags']) List.from(t)],
            signature: map['sig']) {
    if (map['kind'] != event.kind) {
      throw Exception(
          'Kind mismatch! Incoming JSON kind (${map['kind']}) is not of the kind of type $E (${event.kind})');
    }

    final kindCheck = switch (event.kind) {
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

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': event.id,
      'content': event.content,
      'created_at': event.createdAt.toInt(),
      'pubkey': event.pubkey,
      'kind': event.kind,
      'tags': event.tags,
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

  void addLinkedEvent(Event e,
      {String? relayUrl, EventMarker? marker, String? pubkey}) {
    event.addTag('e', [
      e.event.id,
      relayUrl ?? "",
      if (marker != null) marker.name,
      if (pubkey != null) pubkey
    ]);
  }

  void removeLinkedEvent(Event e) => event.removeTag('e', e.event.id);

  void addLinkedUser(Profile u) => event.setTag('p', u.pubkey);
  void removeLinkedUser(Profile u) => event.removeTag('p', u.pubkey);
}

enum EventMarker { reply, root, mention }

sealed class PartialEvent<E extends Event<E>>
    with Signable<E>, PartialEventBase<E> {
  @override
  final PartialInternalEvent event = PartialInternalEvent<E>();

  @override
  Map<String, dynamic> toMap() {
    return {
      'content': event.content,
      'created_at': event.createdAt.toInt(),
      'kind': event.kind,
      'tags': event.tags,
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
  List<List<String>> get tags;

  Set<String> get linkedEvents => getTagSet('e');
  Set<ReplaceableEventLink> get linkedReplaceableEvents {
    return getTagSet('a').map((e) => e.toReplaceableLink()).toSet();
  }

  String? getTag(String key) {
    return BaseUtil.getTag(tags, key);
  }

  Set<String> getTagSet(String key) => BaseUtil.getTagSet(tags, key);

  bool containsTag(String key) => BaseUtil.containsTag(tags, key);
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
  List<List<String>> tags = [];

  void addTag(String key, Object? value) {
    if (value == null) return;
    if (value is Iterable) {
      return tags.add(
        [key, ...value.nonNulls.cast()],
      );
    }
    tags.add([key, value.toString()]);
  }

  void removeTag(String key, [String? value]) {
    tags.removeWhere(
        (tag) => tag.first == key && (value != null ? tag[1] == value : true));
  }

  void setTag(String key, Object? value) {
    if (value == null) return;
    removeTag(key);
    addTag(key, value);
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
  String get identifier => event.getTag('d')!;

  @override
  ReplaceableEventLink getReplaceableEventLink({String? pubkey}) =>
      (event.kind, pubkey ?? event.pubkey, identifier);
}

abstract class ParameterizableReplaceablePartialEvent<E extends Event<E>>
    extends ReplaceablePartialEvent<E> implements IdentifierMixin {
  @override
  String? get identifier => event.getTag('d');
  set identifier(String? value) => event.setTag('d', value);
}

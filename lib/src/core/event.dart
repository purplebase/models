part of models;

mixin EventBase<E extends Event<E>> {
  InternalEvent get internal;
  Map<String, dynamic> toMap();
}

typedef EventConstructor<E extends Event<E>> = E Function(
    Map<String, dynamic>, Ref ref);

// Event

sealed class Event<E extends Event<E>>
    with EquatableMixin
    implements EventBase<E> {
  final Ref ref;

  @override
  final ImmutableInternalEvent internal;

  late final BelongsTo<Profile> author;
  late final HasMany<Reaction> reactions;
  late final HasMany<Zap> zaps;
  late final HasMany<TargetedPublication> targetedPublications;

  Event._internal(this.ref, this.internal) {
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

    // Generic relationships
    author = BelongsTo(ref, RequestFilter<Profile>(authors: {internal.pubkey}));
    reactions = HasMany(ref, RequestFilter(tags: internal.addressableIdTagMap));
    zaps = HasMany(ref, RequestFilter(tags: internal.addressableIdTagMap));
    targetedPublications = HasMany(
        ref,
        RequestFilter(tags: {
          '#d': {id}
        }));
  }

  Event.fromMap(Map<String, dynamic> map, Ref ref)
      : this._internal(ref, ImmutableInternalEvent<E>(map));

  String get id => internal.addressableId;
  DateTime get createdAt => internal.createdAt;

  Future<Map<String, dynamic>> processMetadata() async {
    return {};
  }

  Map<String, dynamic> transformEventMap(Map<String, dynamic> event) {
    return event;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': internal.id,
      'content': internal.content,
      'created_at': internal.createdAt.toSeconds(),
      'pubkey': internal.pubkey,
      'kind': internal.kind,
      'tags': internal.tags,
      'sig': internal.signature,
    };
  }

  @override
  List<Object?> get props => [internal.id];

  @override
  String toString() {
    return toMap().toString();
  }

  // Registry related functions

  static final Map<String, ({int kind, EventConstructor constructor})>
      _modelRegistry = {};

  static void registerModel<E extends Event<E>>(
      {required int kind, required EventConstructor<E> constructor}) {
    _modelRegistry[E.toString()] = (kind: kind, constructor: constructor);
  }

  static Exception _unregisteredException<T>() => Exception(
      'Type $T has not been registered. Make sure to register it with Event.registerModel.');

  static int _kindFor<E extends Event<dynamic>>() {
    final kind = Event._modelRegistry[E.toString()]?.kind;
    if (kind == null) {
      throw _unregisteredException();
    }
    return kind;
  }

  static EventConstructor<E>? getConstructorFor<E extends Event<E>>() {
    final constructor =
        _modelRegistry[E.toString()]?.constructor as EventConstructor<E>?;
    if (constructor == null) {
      throw _unregisteredException();
    }
    return constructor;
  }

  static EventConstructor<Event<dynamic>>? getConstructorForKind(int kind) {
    final constructor = _modelRegistry.values
        .firstWhereOrNull((v) => v.kind == kind)
        ?.constructor;
    if (constructor == null) {
      throw _unregisteredException();
    }
    return constructor;
  }
}

sealed class PartialEvent<E extends Event<E>>
    with Signable<E>
    implements EventBase<E> {
  @override
  final PartialInternalEvent internal = PartialInternalEvent<E>();

  String getEventId(String pubkey) {
    final data = [
      0,
      pubkey.toLowerCase(),
      internal.createdAt.toSeconds(),
      internal.kind,
      internal.tags,
      internal.content
    ];
    final digest =
        sha256.convert(Uint8List.fromList(utf8.encode(json.encode(data))));
    return digest.toString();
  }

  void linkEvent(Event e, {String? relayUrl, String? marker, String? pubkey}) {
    if (e is ReplaceableEvent) {
      internal.addTag('a', [e.id]);
    } else {
      internal.addTag('e', [
        e.id,
        if (relayUrl != null) relayUrl,
        if (marker != null) marker,
        if (pubkey != null) pubkey
      ]);
    }
  }

  void unlinkEvent(Event e) {
    internal.removeTagWithValue(e is ReplaceableEvent ? 'a' : 'e', e.id);
  }

  void linkProfile(Profile p) => internal.setTagValue('p', p.pubkey);
  void unlinkProfile(Profile u) => internal.removeTagWithValue('p', u.pubkey);

  @override
  Map<String, dynamic> toMap() {
    return {
      'content': internal.content,
      'created_at': internal.createdAt.toSeconds(),
      'kind': internal.kind,
      'tags': internal.tags,
    };
  }

  @override
  String toString() {
    return jsonEncode(toMap());
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

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
    author =
        BelongsTo(ref, RequestFilter(kinds: {0}, authors: {internal.pubkey}));

    reactions = HasMany<Reaction>(
        ref, RequestFilter(kinds: {7}, tags: internal.addressableIdTagMap));

    zaps = HasMany<Zap>(
        ref, RequestFilter(kinds: {9735}, tags: internal.addressableIdTagMap));

    targetedPublications = HasMany<TargetedPublication>(
        ref,
        RequestFilter(kinds: {
          30222
        }, tags: {
          '#d': {id}
        }));
  }

  Event.fromMap(Map<String, dynamic> map, Ref ref)
      : this._internal(ref, ImmutableInternalEvent<E>(map));

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

  // Registerable mappings
  static final Map<String, ({int kind, EventConstructor constructor})> types = {
    'Profile': (kind: 0, constructor: Profile.fromMap),
    'Note': (kind: 1, constructor: Note.fromMap),
    'ContactList': (kind: 3, constructor: ContactList.fromMap),
    'DirectMessage': (kind: 4, constructor: DirectMessage.fromMap),
    'ChatMessage': (kind: 9, constructor: ChatMessage.fromMap),
    'Reaction': (kind: 7, constructor: Reaction.fromMap),
    'FileMetadata': (kind: 1063, constructor: FileMetadata.fromMap),
    'ZapRequest': (kind: 9734, constructor: ZapRequest.fromMap),
    'Zap': (kind: 9735, constructor: Zap.fromMap),
    'Community': (kind: 10222, constructor: Community.fromMap),
    'Article': (kind: 30023, constructor: Article.fromMap),
    'Release': (kind: 30063, constructor: Release.fromMap),
    'TargetedPublication': (
      kind: 30222,
      constructor: TargetedPublication.fromMap
    ),
    'AppCurationSet': (kind: 30267, constructor: AppCurationSet.fromMap),
    'App': (kind: 32267, constructor: App.fromMap),
  };

  static int kindFor<E extends Event<E>>() => Event.types[E.toString()]!.kind;

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

  static EventConstructor<Event<dynamic>>? getConstructorForKind(int kind) {
    return types.values.firstWhereOrNull((v) => v.kind == kind)?.constructor;
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

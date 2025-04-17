part of models;

mixin ModelBase<E extends Model<E>> {
  EventBase get event;
  Map<String, dynamic> toMap();
}

typedef ModelConstructor<E extends Model<E>> = E Function(
    Map<String, dynamic>, Ref ref);

// Model

sealed class Model<E extends Model<E>>
    with EquatableMixin
    implements ModelBase<E> {
  final Ref ref;
  final StorageNotifier storage;

  @override
  final ImmutableEvent event;

  late final BelongsTo<Profile> author;
  late final HasMany<Reaction> reactions;
  late final HasMany<Zap> zaps;
  late final HasMany<TargetedPublication> targetedPublications;

  Model._(this.ref, this.event)
      : storage = ref.read(storageNotifierProvider.notifier) {
    final kindCheck = switch (event.kind) {
      >= 10000 && < 20000 || 0 || 3 => this is ReplaceableModel,
      >= 20000 && < 30000 => this is EphemeralModel,
      >= 30000 && < 40000 => this is ParameterizableReplaceableModel,
      _ => this is RegularModel,
    };

    if (!kindCheck) {
      throw Exception(
          'Kind ${event.kind} does not match the type of model: regular, replaceable, etc. Check the model definition inherits the right one.');
    }

    // Generic relationships
    author = BelongsTo(ref, RequestFilter<Profile>(authors: {event.pubkey}));
    reactions = HasMany(ref, RequestFilter(tags: event.addressableIdTagMap));
    zaps = HasMany(ref, RequestFilter(tags: event.addressableIdTagMap));
    targetedPublications = HasMany(
        ref,
        RequestFilter(tags: {
          '#d': {id}
        }));
  }

  Model.fromMap(Map<String, dynamic> map, Ref ref)
      : this._(ref, ImmutableEvent<E>(map));

  String get id => event.addressableId;
  DateTime get createdAt => event.createdAt;

  Future<Map<String, dynamic>> processMetadata() async {
    return {};
  }

  Map<String, dynamic> transformMap(Map<String, dynamic> map) {
    if (!storage.config.keepSignatures) {
      map['sig'] = null;
    }
    return map;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': event.id,
      'content': event.content,
      'created_at': event.createdAt.toSeconds(),
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

  // Storage-related

  Future<void> save() {
    return storage.save({this});
  }

  // Registry related functions

  static final Map<String, ({int kind, ModelConstructor constructor})>
      _modelRegistry = {};

  static void register<E extends Model<E>>(
      {required int kind, required ModelConstructor<E> constructor}) {
    _modelRegistry[E.toString()] = (kind: kind, constructor: constructor);
  }

  static Exception _unregisteredException<T>() => Exception(
      'Type $T has not been registered. Make sure to register it with Model.registerModel.');

  static int _kindFor<E extends Model<dynamic>>() {
    final kind = Model._modelRegistry[E.toString()]?.kind;
    if (kind == null) {
      throw _unregisteredException();
    }
    return kind;
  }

  static ModelConstructor<E>? getConstructorFor<E extends Model<E>>() {
    final constructor =
        _modelRegistry[E.toString()]?.constructor as ModelConstructor<E>?;
    if (constructor == null) {
      throw _unregisteredException();
    }
    return constructor;
  }

  static ModelConstructor<Model<dynamic>>? getConstructorForKind(int kind) {
    final constructor = _modelRegistry.values
        .firstWhereOrNull((v) => v.kind == kind)
        ?.constructor;
    if (constructor == null) {
      throw _unregisteredException();
    }
    return constructor;
  }
}

sealed class PartialModel<E extends Model<E>>
    with Signable<E>
    implements ModelBase<E> {
  @override
  final PartialEvent event = PartialEvent<E>();

  String getEventId(String pubkey) {
    final data = [
      0,
      pubkey.toLowerCase(),
      event.createdAt.toSeconds(),
      event.kind,
      event.tags,
      event.content
    ];
    final digest =
        sha256.convert(Uint8List.fromList(utf8.encode(json.encode(data))));
    return digest.toString();
  }

  void linkModel(Model model,
      {String? relayUrl, String? marker, String? pubkey}) {
    if (model is ReplaceableModel) {
      event.addTag('a', [model.id]);
    } else {
      event.addTag('e', [
        model.id,
        if (relayUrl != null) relayUrl,
        if (marker != null) marker,
        if (pubkey != null) pubkey
      ]);
    }
  }

  void unlinkModel(Model model) {
    event.removeTagWithValue(model is ReplaceableModel ? 'a' : 'e', model.id);
  }

  void linkProfile(Profile p) => event.setTagValue('p', p.pubkey);
  void unlinkProfile(Profile u) => event.removeTagWithValue('p', u.pubkey);

  @override
  Map<String, dynamic> toMap() {
    return {
      'content': event.content,
      'created_at': event.createdAt.toSeconds(),
      'kind': event.kind,
      'tags': event.tags,
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

abstract class RegularModel<E extends Model<E>> = Model<E> with _EmptyMixin;
abstract class RegularPartialModel<E extends Model<E>> = PartialModel<E>
    with _EmptyMixin;

abstract class EphemeralModel<E extends Model<E>> = Model<E> with _EmptyMixin;
abstract class EphemeralPartialModel<E extends Model<E>> = PartialModel<E>
    with _EmptyMixin;

abstract class ReplaceableModel<E extends Model<E>> extends Model<E> {
  @override
  ImmutableReplaceableEvent<E> get event =>
      super.event as ImmutableReplaceableEvent<E>;

  ReplaceableModel.fromMap(Map<String, dynamic> map, Ref ref)
      : this._(ref, ImmutableReplaceableEvent<E>(map));

  ReplaceableModel._(Ref ref, ImmutableReplaceableEvent event)
      : super._(ref, event);
}

abstract class ReplaceablePartialModel<E extends Model<E>> = PartialModel<E>
    with _EmptyMixin;

abstract class ParameterizableReplaceableModel<E extends Model<E>>
    extends ReplaceableModel<E> {
  @override
  ImmutableParameterizableReplaceableEvent<E> get event =>
      super.event as ImmutableParameterizableReplaceableEvent<E>;

  ParameterizableReplaceableModel.fromMap(Map<String, dynamic> map, Ref ref)
      : super._(ref, ImmutableParameterizableReplaceableEvent<E>(map)) {
    if (!event.containsTag('d')) {
      throw Exception('Model must contain a `d` tag');
    }
  }
}

abstract class ParameterizableReplaceablePartialEvent<E extends Model<E>>
    extends ReplaceablePartialModel<E> {
  String? get identifier => event.getFirstTagValue('d');
  set identifier(String? value) => event.setTagValue('d', value);
}

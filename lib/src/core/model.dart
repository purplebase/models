part of models;

mixin ModelBase<E extends Model<E>> {
  EventBase get event;
  Map<String, dynamic> toMap();
}

/// A domain model entity that wraps a signed, finalized nostr event
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
  late final HasMany<GenericRepost> genericReposts;

  Model._(this.ref, this.event)
      : storage = ref.read(storageNotifierProvider.notifier) {
    // Process metadata every time we construct
    if (event.metadata.isEmpty) {
      event.metadata.addAll(processMetadata());
    }

    // Verify kind and subclasses match
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

    // Set up generic relationships
    author = BelongsTo(
        ref, RequestFilter<Profile>(authors: {event.pubkey}).toRequest());
    reactions = HasMany(ref,
        RequestFilter<Reaction>(tags: event.addressableIdTagMap).toRequest());
    zaps = HasMany(
        ref, RequestFilter<Zap>(tags: event.addressableIdTagMap).toRequest());
    targetedPublications = HasMany(
        ref,
        RequestFilter<TargetedPublication>(tags: {
          '#d': {id}
        }).toRequest());
    genericReposts = HasMany(
        ref,
        RequestFilter<GenericRepost>(tags: {
          '#e': {event.id}
        }).toRequest());
  }

  Model.fromMap(Map<String, dynamic> map, Ref ref)
      : this._(ref, ImmutableEvent<E>(map));

  // General wrapper getters

  String get id => event.addressableId;
  DateTime get createdAt => event.createdAt;

  /// Parse once in-event data that requires expensive decoding,
  /// for instance zap amounts
  Map<String, dynamic> processMetadata() {
    return {};
  }

  /// Map transformations before the event is fed into the constructor,
  /// for instance to strip signatures
  @mustCallSuper
  Map<String, dynamic> transformMap(Map<String, dynamic> map) {
    if (!storage.config.keepSignatures) {
      map['sig'] = null;
    }
    return map;
  }

  @override
  Map<String, dynamic> toMap() {
    return event.toMap();
  }

  P toPartial<P extends PartialModel<E>>() {
    return Model._getPartialConstructorFor<E>()!.call(toMap()) as P;
  }

  /// Models are equal when they event IDs are (not their addressable IDs)
  @override
  List<Object?> get props => [event.id];

  @override
  String toString() {
    return toMap().toString();
  }

  // Storage-related

  /// Save this model to storage
  Future<void> save() async {
    await storage.save({this});
  }

  /// Publish this model to relays
  Future<void> publish({RemoteSource source = const RemoteSource()}) async {
    await storage.publish({this}, source: source);
  }

  // Registry-related

  static final Map<
      String,
      ({
        int kind,
        ModelConstructor constructor,
        PartialModelConstructor? partialConstructor
      })> _modelRegistry = {};

  /// Registers a new kind and associates it with its domain model
  static void register<E extends Model<E>>(
      {required int kind,
      required ModelConstructor<E> constructor,
      PartialModelConstructor<E>? partialConstructor}) {
    _modelRegistry[E.toString()] = (
      kind: kind,
      constructor: constructor,
      partialConstructor: partialConstructor
    );
  }

  static Exception _unregisteredException<T>() => Exception(
      'Type $T has not been registered. Are you sure you initialized the storage? Otherwise register it with Model.registerModel.');

  static int _kindFor<E extends Model<dynamic>>() {
    final kind = Model._modelRegistry[E.toString()]?.kind;
    if (kind == null) {
      throw _unregisteredException<E>();
    }
    return kind;
  }

  /// Finds the constructor for type parameter [E]
  static ModelConstructor<E>? getConstructorFor<E extends Model<E>>() {
    final constructor =
        _modelRegistry[E.toString()]?.constructor as ModelConstructor<E>?;
    if (constructor == null) {
      throw _unregisteredException();
    }
    return constructor;
  }

  /// Finds the constructor for kind [kind]
  static ModelConstructor<Model<dynamic>>? getConstructorForKind(int kind) {
    final constructor = _modelRegistry.values
        .firstWhereOrNull((v) => v.kind == kind)
        ?.constructor;
    if (constructor == null) {
      throw Exception('Could not find constructor for kind $kind');
    }
    return constructor;
  }

  /// Finds the partial constructor for type parameter [E]
  static PartialModelConstructor<E>?
      _getPartialConstructorFor<E extends Model<E>>() {
    final constructor = _modelRegistry[E.toString()]?.partialConstructor
        as PartialModelConstructor<E>?;
    if (constructor == null) {
      throw _unregisteredException();
    }
    return constructor;
  }
}

/// A mutable domain model entity that wraps a partial nostr event
/// which is meant to be signed
sealed class PartialModel<E extends Model<E>>
    with Signable<E>
    implements ModelBase<E> {
  @override
  final PartialEvent event;

  PartialModel() : event = PartialEvent<E>();

  PartialModel.fromMap(Map<String, dynamic> map) : event = PartialEvent<E>(map);

  final transientData = <String, dynamic>{};

  /// Add an a/e tag of the passed model
  void linkModel(Model model,
      {String? relayUrl, String? marker, String? pubkey}) {
    return linkModelById(model.id,
        isReplaceable: model is ReplaceableModel,
        relayUrl: relayUrl,
        marker: marker,
        pubkey: pubkey);
  }

  void linkModelById(String modelId,
      {bool isReplaceable = false,
      String? relayUrl,
      String? marker,
      String? pubkey}) {
    if (isReplaceable) {
      event.addTag('a', [modelId, if (relayUrl != null) relayUrl]);
    } else {
      // Need to construct array such that nulls are "" until the last non-null value
      // e.g. ["id", "", "reply"]
      final value = [modelId, relayUrl ?? '', marker ?? '', pubkey ?? ''];
      for (final e in value.reversed.toList()) {
        if (e == '') {
          value.removeLast();
        } else {
          break;
        }
      }
      event.addTag('e', value);
    }
  }

  /// Remove a/e tags of the passed model
  void unlinkModel(Model model) {
    return unlinkModelById(model.id, isReplaceable: model is ReplaceableModel);
  }

  void unlinkModelById(String modelId, {bool isReplaceable = false}) {
    event.removeTagWithValue(isReplaceable ? 'a' : 'e', modelId);
  }

  /// Add p tag of the passed profile
  void linkProfile(Profile p) => linkProfileByPubkey(p.pubkey);

  void linkProfileByPubkey(String p) => event.setTagValue('p', p);

  /// Remove p tag of the passed profile
  void unlinkProfile(Profile p) => unlinkProfileByPubkey(p.pubkey);

  void unlinkProfileByPubkey(String p) => event.removeTagWithValue('p', p);

  Set<String> get tags => event.getTagSetValues('t');
  set tags(Set<String> values) {
    event.addTagValues('t', values);
  }

  @override
  Map<String, dynamic> toMap() {
    return event.toMap();
  }

  @override
  String toString() {
    return jsonEncode(toMap());
  }
}

// Event types

// Create an empty mixin in order to use the = class definitions
mixin _EmptyMixin {}

/// A base domain model class of a regular event
abstract class RegularModel<E extends Model<E>> = Model<E> with _EmptyMixin;
abstract class RegularPartialModel<E extends Model<E>> = PartialModel<E>
    with _EmptyMixin;

/// A base domain model class of an ephemeral event
abstract class EphemeralModel<E extends Model<E>> = Model<E> with _EmptyMixin;
abstract class EphemeralPartialModel<E extends Model<E>> = PartialModel<E>
    with _EmptyMixin;

/// A base domain model class of a replaceable event
abstract class ReplaceableModel<E extends Model<E>> extends Model<E> {
  @override
  ImmutableReplaceableEvent<E> get event =>
      super.event as ImmutableReplaceableEvent<E>;

  ReplaceableModel.fromMap(Map<String, dynamic> map, Ref ref)
      : this._(ref, ImmutableReplaceableEvent<E>(map));

  ReplaceableModel._(Ref ref, ImmutableReplaceableEvent event)
      : super._(ref, event);
}

abstract class ReplaceablePartialModel<E extends Model<E>>
    extends PartialModel<E> {
  ReplaceablePartialModel() : super();
  ReplaceablePartialModel.fromMap(super.map) : super.fromMap();
}

/// A base domain model class of a parameterizable replaceable event (d tag)
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

  String get identifier => event.identifier;
}

abstract class ParameterizableReplaceablePartialModel<E extends Model<E>>
    extends ReplaceablePartialModel<E> {
  ParameterizableReplaceablePartialModel() : super();
  ParameterizableReplaceablePartialModel.fromMap(super.map) : super.fromMap();

  String? get identifier => event.getFirstTagValue('d');
  set identifier(String? value) => event.setTagValue('d', value);
}

typedef ModelConstructor<E extends Model<dynamic>> = E Function(
    Map<String, dynamic>, Ref ref);

typedef PartialModelConstructor<E extends Model<E>> = PartialModel<E> Function(
    Map<String, dynamic>);

/// Annotation to mark a model class for automatic partial model generation.
///
/// When applied to a model class that extends RegularModel, EphemeralModel,
/// ReplaceableModel, or ParameterizableReplaceableModel, the code generator
/// will create a corresponding partial model class.
class GeneratePartialModel {
  const GeneratePartialModel();
}

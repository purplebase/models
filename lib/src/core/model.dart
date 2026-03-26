import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';

import 'event.dart';
import 'types.dart';
import '../relationship/relationship.dart';
import '../filter/request_filter.dart';
import '../signer/signer.dart';
import '../signer/dummy_signer.dart';
import '../source/remote_source.dart';
import '../storage/storage_notifier.dart';
import '../utils/utils.dart';
import '../utils/async.dart';

import '../models/profile.dart';
import '../models/reaction.dart';
import '../models/zap.dart';
import '../models/targeted_publication.dart';
import '../models/generic_repost.dart';

mixin ModelBase<E extends Model<dynamic>> {
  EventBase get event;
  Map<String, dynamic> toMap();
}

abstract class Model<E extends Model<dynamic>>
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
    if (event.metadata.isEmpty) {
      event.metadata.addAll(processMetadata());
    }

    final kindCheck = switch (event.kind) {
      >= 10000 && < 20000 || 0 || 3 => this is ReplaceableModel,
      >= 20000 && < 30000 => this is EphemeralModel,
      >= 30000 && < 40000 => this is ParameterizableReplaceableModel,
      _ => this is RegularModel,
    };

    if (!kindCheck) {
      throw Exception(
        'Kind ${event.kind} does not match the type of model: regular, replaceable, etc. Check the model definition inherits the right one.',
      );
    }

    author = BelongsTo(
      ref,
      RequestFilter<Profile>(authors: {event.pubkey}).toRequest(),
    );
    reactions = HasMany(
      ref,
      RequestFilter<Reaction>(tags: event.addressableIdTagMap).toRequest(),
    );
    zaps = HasMany(
      ref,
      RequestFilter<Zap>(tags: event.addressableIdTagMap).toRequest(),
    );
    targetedPublications = HasMany(
      ref,
      RequestFilter<TargetedPublication>(
        tags: {
          '#d': {id},
        },
      ).toRequest(),
    );
    genericReposts = HasMany(
      ref,
      RequestFilter<GenericRepost>(
        tags: {
          '#e': {event.id},
        },
      ).toRequest(),
    );
  }

  Model.fromMap(Map<String, dynamic> map, Ref ref)
      : this._(ref, ImmutableEvent<E>(map));

  String get id => event.addressableId;
  String get pubkey => event.pubkey;
  DateTime get createdAt => event.createdAt;
  Set<String> get tags => event.getTagSetValues('t');

  /// Pubkeys of communities this event belongs to, from `h` tags (hex).
  Set<String> get communityKeys => event.getTagSetValues('h');

  Map<String, dynamic> processMetadata() {
    return {};
  }

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

  P toPartial<P extends PartialModel<dynamic>>() {
    return Model._getPartialConstructorFor<E>()!.call(toMap()) as P;
  }

  Future<void> save() async {
    await storage.save({this});
  }

  Future<void> publish({RemoteSource source = const RemoteSource()}) async {
    await storage.publish({this}, source: source);
  }

  @override
  List<Object?> get props => [event.id];

  @override
  String toString() {
    return toMap().toString();
  }

  // Registry

  static final Map<
    String,
    ({
      int kind,
      ModelConstructor constructor,
      PartialModelConstructor? partialConstructor,
    })
  > _modelRegistry = {};

  static final Map<String, int> _partialTypeToKind = {};

  static void register<E extends Model<dynamic>>({
    required int kind,
    required ModelConstructor<E> constructor,
    PartialModelConstructor? partialConstructor,
  }) {
    final typeName = E.toString();
    _modelRegistry[typeName] = (
      kind: kind,
      constructor: constructor,
      partialConstructor: partialConstructor,
    );
    _partialTypeToKind['Partial$typeName'] = kind;
  }

  static int? _kindForPartialType(String partialTypeName) {
    return _partialTypeToKind[partialTypeName];
  }

  static Exception _unregisteredException<T>() => Exception(
        'Type $T has not been registered. Are you sure you initialized the storage? Otherwise register it with Model.register.',
      );

  static int kindFor<E extends Model<dynamic>>() {
    final kind = Model._modelRegistry[E.toString()]?.kind;
    if (kind == null) {
      throw _unregisteredException<E>();
    }
    return kind;
  }

  static bool isModelOfDynamic<E extends Model<dynamic>>() =>
      <Model<dynamic>>[] is List<E>;

  static ModelConstructor<E>? getConstructorFor<E extends Model<dynamic>>() {
    final constructor =
        _modelRegistry[E.toString()]?.constructor as ModelConstructor<E>?;
    if (constructor == null) {
      throw _unregisteredException<E>();
    }
    return constructor;
  }

  static ModelConstructor<Model<dynamic>>? getConstructorForKind(int kind) {
    final constructor = _modelRegistry.values
        .where((v) => v.kind == kind)
        .map((v) => v.constructor)
        .firstOrNull;
    if (constructor == null) {
      throw Exception('Could not find constructor for kind $kind');
    }
    return constructor;
  }

  static PartialModelConstructor<E>?
      _getPartialConstructorFor<E extends Model<dynamic>>() {
    final constructor = _modelRegistry[E.toString()]?.partialConstructor
        as PartialModelConstructor<E>?;
    if (constructor == null) {
      throw _unregisteredException<E>();
    }
    return constructor;
  }

  static void initializeDummySigner(Ref ref) {
    _dummySigner = DummySigner(ref);
  }
}

abstract class PartialModel<E extends Model<dynamic>>
    with Signable<E>
    implements ModelBase<E> {
  @override
  late final PartialEvent event;

  final transientData = <String, dynamic>{};

  PartialModel() {
    final typeName = runtimeType.toString().split('<').first;
    final kind = Model._kindForPartialType(typeName);
    event = PartialEvent<E>(null, kind);
  }

  PartialModel.fromMap(Map<String, dynamic> map) {
    final typeName = runtimeType.toString().split('<').first;
    final kind = Model._kindForPartialType(typeName);
    event = PartialEvent<E>(map, kind);
  }

  void linkModel(
    Model model, {
    String? relayUrl,
    String? marker,
    String? pubkey,
  }) {
    return linkModelById(
      model.id,
      isReplaceable: model is ReplaceableModel,
      relayUrl: relayUrl,
      marker: marker,
      pubkey: pubkey,
    );
  }

  void linkModelById(
    String modelId, {
    bool isReplaceable = false,
    String? relayUrl,
    String? marker,
    String? pubkey,
  }) {
    if (isReplaceable) {
      event.addTag('a', [modelId, if (relayUrl != null) relayUrl]);
    } else {
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

  void unlinkModel(Model model) {
    return unlinkModelById(model.id, isReplaceable: model is ReplaceableModel);
  }

  void unlinkModelById(String modelId, {bool isReplaceable = false}) {
    event.removeTagWithValue(isReplaceable ? 'a' : 'e', modelId);
  }

  void linkProfileByPubkey(String p) => event.setTagValue('p', p);
  void unlinkProfileByPubkey(String p) => event.removeTagWithValue('p', p);

  Set<String> get tags => event.getTagSetValues('t');
  set tags(Set<String> values) {
    event.addTagValues('t', values);
  }

  /// Adds a community pubkey to the `h` tag. Accepts npub or hex.
  void addCommunityKey(String pubkey) =>
      event.addTagValue('h', Utils.decodeShareableToString(pubkey));

  /// Removes a community pubkey from the `h` tag. Accepts npub or hex.
  void removeCommunityKey(String pubkey) =>
      event.removeTagWithValue('h', Utils.decodeShareableToString(pubkey));

  Future<void> prepareForSigning(Signer signer) async {}

  @override
  Map<String, dynamic> toMap() {
    return event.toMap();
  }

  @override
  String toString() {
    return jsonEncode(toMap());
  }
}

// Event type classes

mixin _EmptyMixin {}

abstract class RegularModel<E extends Model<dynamic>> = Model<E>
    with _EmptyMixin;
abstract class RegularPartialModel<E extends Model<dynamic>> = PartialModel<E>
    with _EmptyMixin;

abstract class EphemeralModel<E extends Model<dynamic>> = Model<E>
    with _EmptyMixin;
abstract class EphemeralPartialModel<E extends Model<dynamic>> = PartialModel<E>
    with _EmptyMixin;

abstract class ReplaceableModel<E extends Model<dynamic>> extends Model<E> {
  @override
  ImmutableReplaceableEvent<E> get event =>
      super.event as ImmutableReplaceableEvent<E>;

  ReplaceableModel.fromMap(Map<String, dynamic> map, Ref ref)
      : this._(ref, ImmutableReplaceableEvent<E>(map));

  ReplaceableModel._(Ref ref, ImmutableReplaceableEvent event)
      : super._(ref, event);
}

abstract class ReplaceablePartialModel<E extends Model<dynamic>>
    extends PartialModel<E> {
  ReplaceablePartialModel() : super();
  ReplaceablePartialModel.fromMap(super.map) : super.fromMap();
}

abstract class ParameterizableReplaceableModel<E extends Model<dynamic>>
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

abstract class ParameterizableReplaceablePartialModel<E extends Model<dynamic>>
    extends ReplaceablePartialModel<E> {
  ParameterizableReplaceablePartialModel() : super();
  ParameterizableReplaceablePartialModel.fromMap(super.map) : super.fromMap();

  String? get identifier => event.getFirstTagValue('d');
  set identifier(String? value) => event.setTagValue('d', value);
}

DummySigner? _dummySigner;

mixin Signable<E extends Model<dynamic>> {
  Future<E> signWith(Signer signer) async {
    final partialModel = this as PartialModel<E>;
    await partialModel.prepareForSigning(signer);
    final signed = await signer.sign<E>([partialModel]);
    return signed.first;
  }

  E dummySign([String? pubkey]) {
    pubkey ??= Utils.generateRandomHex64();
    final partialModel = this as PartialModel<E>;

    final dummySigner = DummySigner(_dummySigner!.ref, pubkey: pubkey);
    // ignore: invalid_use_of_protected_member
    dummySigner.internalSetPubkey(pubkey);
    runSync(() => partialModel.prepareForSigning(dummySigner));

    return _dummySigner!.signSync(partialModel, pubkey: pubkey);
  }
}

extension SignerExtension<E extends Model<dynamic>>
    on Iterable<PartialModel<Model>> {
  Future<List<E>> signWith(Signer signer) async {
    return await signer.sign<E>(toList());
  }
}

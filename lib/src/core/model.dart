import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'encryptable.dart';
import 'event.dart';
import 'null_storage_reader.dart';
import 'storage_reader.dart';
import 'model_registry.dart';
import '../relationship/relationship.dart';
import '../filter/request_filter.dart';
import '../signer/signer.dart';
import '../utils/utils.dart';

// Model type imports for generic relationships defined on base Model.
import '../models/profile.dart';
import '../models/reaction.dart';
import '../models/zap.dart';
import '../models/targeted_publication.dart';
import '../models/generic_repost.dart';

export 'storage_reader.dart';

/// Base mixin for all domain model entities.
mixin ModelBase<E extends Model<dynamic>> {
  EventBase get event;
  Map<String, dynamic> toMap();
}

/// A domain model entity that wraps a signed, finalized Nostr event.
///
/// This is the base abstract class for all Nostr models. Models are pure data
/// objects that use [StorageReader] for relationship resolution instead of Riverpod.
abstract class Model<E extends Model<dynamic>>
    with EquatableMixin
    implements ModelBase<E> {
  final StorageReader _reader;

  @override
  final ImmutableEvent event;

  /// Access the storage reader for relationship resolution.
  StorageReader get reader => _reader;

  /// The author (profile) of this model.
  late final BelongsTo<Profile> author;

  /// All reactions to this model.
  late final HasMany<Reaction> reactions;

  /// All zaps (lightning payments) to this model.
  late final HasMany<Zap> zaps;

  /// All targeted publications of this model.
  late final HasMany<TargetedPublication> targetedPublications;

  /// All generic reposts of this model.
  late final HasMany<GenericRepost> genericReposts;

  Model._(this._reader, this.event) {
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
        'Kind ${event.kind} does not match the type of model: regular, replaceable, etc. Check the model definition inherits the right one.',
      );
    }

    // Set up generic relationships
    author = BelongsTo(
      _reader,
      RequestFilter<Profile>(authors: {event.pubkey}).toRequest(),
    );
    reactions = HasMany(
      _reader,
      RequestFilter<Reaction>(tags: event.addressableIdTagMap).toRequest(),
    );
    zaps = HasMany(
      _reader,
      RequestFilter<Zap>(tags: event.addressableIdTagMap).toRequest(),
    );
    targetedPublications = HasMany(
      _reader,
      RequestFilter<TargetedPublication>(
        tags: {
          '#d': {id},
        },
      ).toRequest(),
    );
    genericReposts = HasMany(
      _reader,
      RequestFilter<GenericRepost>(
        tags: {
          '#e': {event.id},
        },
      ).toRequest(),
    );
  }

  Model.fromMap(Map<String, dynamic> map, StorageReader reader)
      : this._(reader, ImmutableEvent<E>(map));

  // General wrapper getters

  /// The unique addressable identifier for this model.
  String get id => event.addressableId;

  /// Public key of the author of this model.
  String get pubkey => event.pubkey;

  /// When this model was created.
  DateTime get createdAt => event.createdAt;

  /// Topic tags (hashtags) for this model.
  Set<String> get tags => event.getTagSetValues('t');

  /// Parse once in-event data that requires expensive decoding.
  Map<String, dynamic> processMetadata() {
    return {};
  }

  /// Map transformations before the event is fed into the constructor.
  /// Override in subclasses for model-specific transformations.
  @mustCallSuper
  Map<String, dynamic> transformMap(Map<String, dynamic> map) {
    return map;
  }

  @override
  Map<String, dynamic> toMap() {
    return event.toMap();
  }

  /// Convert this model to its partial representation.
  P toPartial<P extends PartialModel<dynamic>>() {
    return ModelRegistry.instance.getPartialConstructorFor<E>()!.call(toMap()) as P;
  }

  /// Models are equal when their raw event IDs match.
  @override
  List<Object?> get props => [event.id];

  @override
  String toString() {
    return toMap().toString();
  }
}

/// Abstract interface for a mutable domain model entity that wraps a partial
/// Nostr event which is meant to be signed.
abstract class PartialModel<E extends Model<dynamic>>
    with Signable<E>
    implements ModelBase<E> {
  @override
  late final PartialEvent event;

  /// Transient data that doesn't get included in the event.
  final transientData = <String, dynamic>{};

  PartialModel() {
    final typeName = runtimeType.toString().split('<').first;
    final kind = ModelRegistry.instance.kindForPartialType(typeName);
    event = PartialEvent<E>(null, kind);
  }

  PartialModel.fromMap(Map<String, dynamic> map) {
    final typeName = runtimeType.toString().split('<').first;
    final kind = ModelRegistry.instance.kindForPartialType(typeName);
    event = PartialEvent<E>(map, kind);
  }

  /// Add an a/e tag referencing the passed model.
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

  /// Add an a/e tag referencing a model by its ID.
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

  /// Remove a/e tags of the passed model
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

  /// Hook method called before signing to prepare the event.
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

/// A base domain model class of a regular event
abstract class RegularModel<E extends Model<dynamic>> = Model<E>
    with _EmptyMixin;
abstract class RegularPartialModel<E extends Model<dynamic>> = PartialModel<E>
    with _EmptyMixin;

/// A base domain model class of an ephemeral event
abstract class EphemeralModel<E extends Model<dynamic>> = Model<E>
    with _EmptyMixin;
abstract class EphemeralPartialModel<E extends Model<dynamic>> = PartialModel<E>
    with _EmptyMixin;

/// A base domain model class of a replaceable event
abstract class ReplaceableModel<E extends Model<dynamic>> extends Model<E> {
  @override
  ImmutableReplaceableEvent<E> get event =>
      super.event as ImmutableReplaceableEvent<E>;

  ReplaceableModel.fromMap(Map<String, dynamic> map, StorageReader reader)
      : this._(reader, ImmutableReplaceableEvent<E>(map));

  ReplaceableModel._(StorageReader reader, ImmutableReplaceableEvent event)
      : super._(reader, event);
}

abstract class ReplaceablePartialModel<E extends Model<dynamic>>
    extends PartialModel<E> {
  ReplaceablePartialModel() : super();
  ReplaceablePartialModel.fromMap(super.map) : super.fromMap();
}

/// A base domain model class of a parameterizable replaceable event (d tag)
abstract class ParameterizableReplaceableModel<E extends Model<dynamic>>
    extends ReplaceableModel<E> {
  @override
  ImmutableParameterizableReplaceableEvent<E> get event =>
      super.event as ImmutableParameterizableReplaceableEvent<E>;

  ParameterizableReplaceableModel.fromMap(
      Map<String, dynamic> map, StorageReader reader)
      : super._(reader, ImmutableParameterizableReplaceableEvent<E>(map)) {
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

/// Signable mixin to make the [signWith] method available on all partial models
mixin Signable<E extends Model<dynamic>> {
  Future<E> signWith(Signer signer) async {
    final partialModel = this as PartialModel<E>;
    await partialModel.prepareForSigning(signer);
    final signed = await signer.sign<E>([partialModel]);
    return signed.first;
  }

  E dummySign([StorageReader? reader, String? pubkey]) {
    pubkey ??= Utils.generateRandomHex64();
    reader ??= const NullStorageReader();
    final partialModel = this as PartialModel<E>;

    // Handle encryption for encryptable models (DirectMessage, AppStack, etc.)
    if (partialModel is EncryptablePartialModel &&
        partialModel.event.content.isNotEmpty) {
      partialModel.event.content =
          'dummy_nip44_encrypted_${partialModel.event.content.hashCode}_$pubkey';
    }

    final constructor =
        ModelRegistry.instance.getConstructorForKind(partialModel.event.kind)!;
    return constructor.call({
      'id': Utils.getEventId(partialModel.event, pubkey),
      'pubkey': pubkey,
      ...partialModel.toMap(),
    }, reader) as E;
  }
}

extension SignerExtension<E extends Model<dynamic>>
    on Iterable<PartialModel<Model>> {
  Future<List<E>> signWith(Signer signer) async {
    return await signer.sign<E>(toList());
  }
}

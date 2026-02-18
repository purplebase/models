import 'types.dart';
import 'model.dart';

/// Central registry that maps Nostr event kinds to their model constructors.
///
/// Extracted from Model class to be a standalone singleton.
/// Registration still happens in StorageNotifier.initialize().
class ModelRegistry {
  static final instance = ModelRegistry._();
  ModelRegistry._();

  final Map<String, ({
    int kind,
    ModelConstructor constructor,
    PartialModelConstructor? partialConstructor,
  })> _modelRegistry = {};

  /// Maps partial type names to their corresponding kind numbers.
  final Map<String, int> _partialTypeToKind = {};

  /// Registers a new kind and associates it with its domain model.
  void register<E extends Model<dynamic>>({
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

  /// Looks up kind by partial type name (e.g., "PartialSoftwareAsset" -> 3063)
  int? kindForPartialType(String partialTypeName) {
    return _partialTypeToKind[partialTypeName];
  }

  /// Get the kind number for a model type.
  int kindFor<E extends Model<dynamic>>() {
    final kind = _modelRegistry[E.toString()]?.kind;
    if (kind == null) {
      throw _unregisteredException<E>();
    }
    return kind;
  }

  /// Finds the constructor for type parameter [E].
  ModelConstructor<E>? getConstructorFor<E extends Model<dynamic>>() {
    final constructor =
        _modelRegistry[E.toString()]?.constructor as ModelConstructor<E>?;
    if (constructor == null) {
      throw _unregisteredException<E>();
    }
    return constructor;
  }

  /// Finds the constructor for the given Nostr event kind.
  ModelConstructor<Model<dynamic>>? getConstructorForKind(int kind) {
    final constructor = _modelRegistry.values
        .where((v) => v.kind == kind)
        .map((v) => v.constructor)
        .firstOrNull;
    if (constructor == null) {
      throw Exception('Could not find constructor for kind $kind');
    }
    return constructor;
  }

  /// Finds the partial constructor for type parameter [E].
  PartialModelConstructor<E>? getPartialConstructorFor<E extends Model<dynamic>>() {
    final constructor =
        _modelRegistry[E.toString()]?.partialConstructor
            as PartialModelConstructor<E>?;
    if (constructor == null) {
      throw _unregisteredException<E>();
    }
    return constructor;
  }

  /// Check if type [E] is Model<dynamic> (no specific type).
  static bool isModelOfDynamic<E extends Model<dynamic>>() =>
      <Model<dynamic>>[] is List<E>;

  static Exception _unregisteredException<T>() => Exception(
        'Type $T has not been registered. Are you sure you initialized the storage? Otherwise register it with ModelRegistry.instance.register.',
      );
}

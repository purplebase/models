import 'model.dart';
import '../relationship/nested_query.dart';

/// Filter function to discard events before model construction.
/// Return `true` to keep the event, `false` to discard it.
typedef SchemaFilter = bool Function(Map<String, dynamic> event);

/// Callback that returns nested queries for a model's relationships.
typedef AndFunction<E extends Model<dynamic>> = Set<NestedQuery> Function(E)?;

/// Client-side filter applied after model construction.
typedef WhereFunction<E extends Model<dynamic>> = bool Function(E)?;

/// Constructor for creating a Model from a map and StorageReader.
typedef ModelConstructor<E extends Model<dynamic>> =
    E Function(Map<String, dynamic> map, StorageReader reader);

/// Constructor for creating a PartialModel from a map.
typedef PartialModelConstructor<E extends Model<dynamic>> =
    PartialModel<E> Function(Map<String, dynamic>);

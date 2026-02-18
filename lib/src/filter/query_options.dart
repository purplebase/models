import '../core/model.dart';
import '../core/types.dart';

/// Client-side query behavior — never serialized, never sent to relays.
///
/// Separates protocol concerns (RequestFilter) from client concerns.
class QueryOptions<E extends Model<dynamic>> {
  final WhereFunction<E> where;
  final AndFunction<E> and;
  final SchemaFilter? schemaFilter;

  const QueryOptions({this.where, this.and, this.schemaFilter});
}

import 'package:riverpod/riverpod.dart';

import 'model.dart';
import '../relationship/nested_query.dart';

typedef SchemaFilter = bool Function(Map<String, dynamic> event);
typedef AndFunction<E extends Model<dynamic>> = Set<NestedQuery> Function(E)?;
typedef WhereFunction<E extends Model<dynamic>> = bool Function(E)?;

typedef ModelConstructor<E extends Model<dynamic>> =
    E Function(Map<String, dynamic> map, Ref ref);

typedef PartialModelConstructor<E extends Model<dynamic>> =
    PartialModel<E> Function(Map<String, dynamic>);

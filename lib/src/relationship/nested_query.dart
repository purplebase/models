import 'package:equatable/equatable.dart';

import '../core/model.dart';
import '../filter/request.dart';
import '../source/source.dart';

/// Descriptor for a nested query on a relationship.
///
/// Created via [Relationship.query] and returned from the `and` callback.
/// Contains the request to execute plus optional overrides for source and
/// subscription prefix. When these are null, values are inherited from the
/// outer query.
class NestedQuery with EquatableMixin {
  final Request? request;
  final Source? source;
  final String? subscriptionPrefix;
  final Set<NestedQuery> Function(Model<dynamic>)? and;

  const NestedQuery({
    required this.request,
    this.source,
    this.subscriptionPrefix,
    this.and,
  });

  /// Equality is based on request only - used to track streaming state.
  @override
  List<Object?> get props => [request];
}

import 'package:models/src/event.dart';

// TODO: Should relationship APIs be non-blocking?

sealed class Relationship<E extends Event<E>> {}

abstract class BelongsTo<E extends Event<E>> extends Relationship<E> {
  E? get value;
}

class ValueBelongsTo<E extends Event<E>> {
  final String id;
  ValueBelongsTo(this.id);
}

abstract class HasMany<E extends Event<E>> extends Relationship<E> {
  List<E> toList();
}

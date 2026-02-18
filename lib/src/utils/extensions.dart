import 'package:collection/collection.dart';

import '../core/model.dart';
import '../core/model_registry.dart';
import 'utils.dart';

extension StringMaybeExt on String? {
  int? toInt() {
    return this == null ? null : int.tryParse(this!);
  }
}

extension StringExt on String {
  String encodeShareable({required String type}) =>
      Utils.encodeShareableFromString(this, type: type);
  String decodeShareable() => Utils.decodeShareableToString(this);
}

extension DateTimeExt on DateTime {
  int toSeconds() => millisecondsSinceEpoch ~/ 1000;
}

extension IntExt on int {
  DateTime toDate() => DateTime.fromMillisecondsSinceEpoch(this * 1000);
}

extension ModelsExt<E extends Model<dynamic>> on Set<E> {
  List<E> sortByCreatedAt() {
    return sortedByCompare(
        (m) => m.createdAt.millisecondsSinceEpoch, (a, b) => b.compareTo(a));
  }
}

extension MapIterableExt on Iterable<Map<String, dynamic>> {
  Iterable<E> toModels<E extends Model<dynamic>>(StorageReader reader) {
    return map((e) {
      return ModelRegistry.instance.getConstructorForKind(e['kind']!)!.call(e, reader);
    }).cast<E>();
  }
}

part of models;

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
  Iterable<E> toModels<E extends Model<dynamic>>(Ref ref) {
    return map((e) {
      return Model.getConstructorForKind(e['kind']!)!.call(e, ref);
    }).cast<E>();
  }
}

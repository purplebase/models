extension StringMaybeExt on String? {
  int? toInt() {
    return this == null ? null : int.tryParse(this!);
  }
}

extension DateTimeExt on DateTime {
  int toSeconds() => millisecondsSinceEpoch ~/ 1000;
}

extension IntExt on int {
  DateTime toDate() => DateTime.fromMillisecondsSinceEpoch(this * 1000);
}

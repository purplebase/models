import 'package:equatable/equatable.dart';

final class TagValue with EquatableMixin {
  final List<String> values;
  TagValue(this.values) {
    if (values.isEmpty) throw 'empty tag';
  }
  String get value => values.first;

  @override
  List<Object?> get props => values;

  static Map<String, Set<TagValue>> deserialize(Iterable originalTags) {
    final tagList = [for (final t in originalTags) List.from(t).cast<String>()];
    return tagList.fold(<String, Set<TagValue>>{}, (acc, e) {
      if (e.length >= 2) {
        final [name, ...rest] = e;
        acc[name] ??= {};
        if (name == 'e') {
          acc[name]!.add(EventTagValue(rest.first,
              relayUrl: rest[1],
              marker:
                  rest.length > 2 ? EventMarker.fromString(rest[2]) : null));
        } else {
          acc[name]!.add(TagValue(rest));
        }
      }
      return acc;
    });
  }

  static List<List<String>> serialize(Map<String, Set<TagValue>> tags) {
    return [
      for (final e in tags.entries)
        for (final t in e.value) [e.key, ...t.values]
    ];
  }

  @override
  String toString() {
    return values.toString();
  }
}

final class EventTagValue extends TagValue {
  final String? relayUrl;
  final EventMarker? marker;
  final String? pubkey;
  EventTagValue(String value, {this.relayUrl, this.marker, this.pubkey})
      : super([
          value,
          relayUrl ?? "",
          if (marker != null) marker.name,
          if (pubkey != null) pubkey
        ]);
}

enum EventMarker {
  reply,
  root,
  mention;

  static fromString(String value) {
    for (final element in EventMarker.values) {
      if (element.name.toLowerCase() == value.toLowerCase()) {
        return element;
      }
    }
    return null;
  }
}

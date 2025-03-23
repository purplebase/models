import 'dart:async';

import 'package:faker/faker.dart';
import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';

final dummySigner = DummySigner();

class InMemoryRelay {
  final List<Event> _events = [];
  static InMemoryRelay? _instance;
  final Ref ref;

  factory InMemoryRelay(Ref ref) {
    return _instance ??= InMemoryRelay._internal(ref);
  }

  InMemoryRelay._internal(this.ref) {
    // Pre-populate database from provider,
    // happens once as this is a singleton
    save(ref.read(dummyDataProvider));
  }

  void save(List<Event> events) {
    for (final event in events) {
      final existingIndex =
          _events.indexWhere((e) => e.event.id == event.event.id);
      if (existingIndex >= 0) {
        _events[existingIndex] = event;
      } else {
        _events.add(event);
      }
    }
  }

  List<Event> query(RequestFilter req, {bool applyLimit = true}) {
    var results = [..._events];

    if (req.ids.isNotEmpty) {
      results =
          results.where((event) => req.ids.contains(event.event.id)).toList();
    }

    if (req.authors.isNotEmpty) {
      results = results
          .where((event) => req.authors.contains(event.event.pubkey))
          .toList();
    }

    if (req.kinds.isNotEmpty) {
      results = results
          .where((event) => req.kinds.contains(event.event.kind))
          .toList();
    }

    if (req.since != null) {
      results = results
          .where((event) => event.event.createdAt.isAfter(req.since!))
          .toList();
    }

    if (req.until != null) {
      results = results
          .where((event) => event.event.createdAt.isBefore(req.until!))
          .toList();
    }

    if (req.tags.isNotEmpty) {
      results =
          results.where((event) => req.matchesTags(event.event.tags)).toList();
    }

    results.sort((a, b) => b.event.createdAt.compareTo(a.event.createdAt));

    if (applyLimit && req.limit != null && results.length > req.limit!) {
      results = results.sublist(0, req.limit!);
    }

    return results;
  }
}

class DummyStorageNotifier extends StorageNotifier {
  final RequestFilter req;
  final Ref ref;
  late final InMemoryRelay db;
  var applyLimit = true;

  DummyStorageNotifier(this.ref, this.req) : super() {
    db = InMemoryRelay(ref);
    // Execute query and notify
    state = StorageData(db.query(req, applyLimit: applyLimit));
    applyLimit = false;
    // Send request filter to relays
    send(req);
  }

  void save(List<Event> events) {
    db.save(events);
    state = StorageData(db.query(req, applyLimit: applyLimit));
  }

  @override
  void send(RequestFilter req) async {
    await Future.delayed(Duration(seconds: 1));
    final models = [
      for (final _ in List.generate(req.limit ?? 10, (_) {}))
        for (final author in req.authors)
          await PartialNote(faker.lorem.sentence())
              .signWith(dummySigner, withPubkey: author),
    ];
    save(models);

    Timer.periodic(Duration(seconds: 3), (t) async {
      if (mounted) {
        if (t.tick > 2) {
          // state = RelayError(
          //   state.models,
          //   message: 'Server error, closed',
          //   subscriptionId: req.subscriptionId,
          // );
          t.cancel();
        } else {
          final models = [
            for (final author in req.authors)
              await PartialNote(faker.conference.name())
                  .signWith(dummySigner, withPubkey: author),
          ];
          save(models);
        }
      } else {
        print('bro its closed');
        t.cancel();
      }
    });
  }
}

extension IX on RequestFilter {
  bool matchesTags(List<List<String>> eventTags) {
    if (tags.isEmpty) return true;

    // Convert event tags to a map for easier lookup
    Map<String, List<String>> eventTagsMap = {};

    for (final tag in eventTags) {
      if (tag.length >= 2) {
        final tagName = tag[0];
        final tagValue = tag[1];

        if (!eventTagsMap.containsKey(tagName)) {
          eventTagsMap[tagName] = [];
        }

        eventTagsMap[tagName]!.add(tagValue);
      }
    }

    // Check each tag filter
    for (final entry in tags.entries) {
      final tagName = entry.key;
      final requiredValues = entry.value;

      // If this tag name isn't in the event tags, it doesn't match
      if (!eventTagsMap.containsKey(tagName)) {
        return false;
      }

      // If none of the required values match, it doesn't match
      if (!requiredValues
          .any((value) => eventTagsMap[tagName]!.contains(value))) {
        return false;
      }
    }

    return true;
  }
}

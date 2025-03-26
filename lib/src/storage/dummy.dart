import 'dart:async';

import 'package:faker/faker.dart';
import 'package:models/models.dart';
import 'package:models/src/core/utils.dart';
import 'package:riverpod/riverpod.dart';

final dummySigner = DummySigner();

class DummyStorage implements Storage {
  final Map<String, Event> _events = {};
  static DummyStorage? _instance;
  final Ref ref;

  factory DummyStorage(Ref ref) {
    return _instance ??= DummyStorage._internal(ref);
  }

  DummyStorage._internal(this.ref) {
    // Pre-populate database from provider,
    // happens once as this is a singleton
    save(ref.read(dummyDataProvider));
  }

  @override
  Future<void> save(Iterable<Event> events) async {
    for (final event in events) {
      final id = switch (event) {
        ParameterizableReplaceableEvent() => (
            event.internal.kind,
            event.internal.pubkey,
            event.identifier
          ).formatted,
        ReplaceableEvent() =>
          (event.internal.kind, event.internal.pubkey, null).formatted,
        EphemeralEvent() => event.internal.id,
        RegularEvent() => event.internal.id,
      };
      _events[id] = event;
    }
  }

  @override
  Future<List<Event>> queryAsync(RequestFilter req,
      {bool applyLimit = true}) async {
    return query(req, applyLimit: applyLimit);
  }

  @override
  List<Event> query(RequestFilter req, {bool applyLimit = true}) {
    List<Event> results;

    if (req.ids.isNotEmpty) {
      results = _events.entries
          .where((e) => req.ids.contains(e.key))
          .map((e) => e.value)
          .toList();
    } else {
      results = [..._events.values];
    }

    if (req.authors.isNotEmpty) {
      results = results
          .where((event) => req.authors.contains(event.internal.pubkey))
          .toList();
    }

    if (req.kinds.isNotEmpty) {
      results = results
          .where((event) => req.kinds.contains(event.internal.kind))
          .toList();
    }

    if (req.since != null) {
      results = results
          .where((event) => event.internal.createdAt.isAfter(req.since!))
          .toList();
    }

    if (req.until != null) {
      results = results
          .where((event) => event.internal.createdAt.isBefore(req.until!))
          .toList();
    }

    if (req.tags.isNotEmpty) {
      results = results.where((event) {
        // Requested tags should behave like AND: use fold with initial true and acc &&
        return req.tags.entries.fold(true, (acc, entry) {
          final wantedTagKey = entry.key.substring(1); // remove leading '#'
          final wantedTagValues = entry.value;
          // Event tags should behave like OR: use fold with initial false and acc ||
          return acc &&
              event.internal.getTagSetValues(wantedTagKey).fold(false,
                  (acc, currentTagValue) {
                return acc || wantedTagValues.contains(currentTagValue);
              });
        });
      }).toList();
    }

    results
        .sort((a, b) => b.internal.createdAt.compareTo(a.internal.createdAt));

    if (applyLimit && req.limit != null && results.length > req.limit!) {
      results = results.sublist(0, req.limit!);
    }

    if (req.where != null) {
      results = results.where(req.where!).toList();
    }

    return results;
  }

  @override
  Future<void> clear([RequestFilter? req]) async {
    if (req == null) {
      _events.clear();
      return;
    }
    final events = await queryAsync(req);
    _events.removeWhere((_, e) => events.contains(e));
  }
}

class DummyStorageNotifier extends StorageNotifier {
  final RequestFilter req;
  final Ref ref;
  late final DummyStorage db;
  var applyLimit = true;

  DummyStorageNotifier(this.ref, this.req) : super() {
    db = DummyStorage(ref);
    // If no filters were provided, do nothing
    if (req.toMap().isEmpty) {
      return;
    }
    // Execute query and notify
    db.queryAsync(req, applyLimit: applyLimit).then((events) {
      state = StorageData(events);
      applyLimit = false;
      if (!req.storageOnly) {
        // Send request filter to relays
        send(req);
      }
    });
  }

  Future<void> save(List<Event> events) async {
    await db.save(events);
    state = StorageData(await db.queryAsync(req, applyLimit: applyLimit));
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
        t.cancel();
      }
    });
  }
}

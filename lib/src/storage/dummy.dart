import 'dart:async';

import 'package:faker/faker.dart';
import 'package:models/models.dart';
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
      _events[event.id] = event;
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

//

class DummyStorageNotifier extends StorageNotifier {
  final Ref ref;
  late final DummyStorage db;
  var applyLimit = true;

  DummyStorageNotifier(this.ref) : super() {
    db = DummyStorage(ref);
  }

  @override
  Future<void> save(List<Event> events) async {
    await db.save(events);
    state = StorageSignal();
  }

  @override
  Future<void> generateDummyFor(
      {required String pubkey,
      required int kind,
      int amount = 10,
      bool stream = false}) async {
    await Future.delayed(Duration(seconds: 1));

    var profile = db
        .query(RequestFilter(authors: {pubkey}, kinds: {0}))
        .cast<Profile>()
        .firstOrNull;

    profile ??= await PartialProfile(
            name: faker.person.name(),
            nip05: faker.internet.freeEmail(),
            pictureUrl: faker.internet.httpsUrl())
        .signWith(dummySigner, withPubkey: pubkey);

    final models = [
      for (final _ in List.generate(amount, (_) {}))
        await PartialNote(faker.lorem.sentence())
            .signWith(dummySigner, withPubkey: profile.pubkey),
    ];
    await save(models);

    Timer.periodic(Duration(seconds: 3), (t) async {
      if (mounted) {
        if (t.tick > 3) {
          // state = RelayError(
          //   state.models,
          //   message: 'Server error, closed',
          //   subscriptionId: req.subscriptionId,
          // );
          t.cancel();
        } else {
          final models = [
            await PartialNote(faker.conference.name())
                .signWith(dummySigner, withPubkey: profile!.pubkey),
          ];
          await save(models);
        }
      } else {
        t.cancel();
      }
    });
  }
}

//

class DummyRequestNotifier extends RequestNotifier {
  final RequestFilter req;
  final Ref ref;
  late final DummyStorage db;
  var applyLimit = true;

  DummyRequestNotifier(this.ref, this.req) : super() {
    db = DummyStorage(ref);
    // If no filters were provided, do nothing
    if (req.toMap().isEmpty) {
      return;
    }
    // Execute query and notify
    db.queryAsync(req, applyLimit: applyLimit).then((events) {
      print('setting initial state, ${events.length}');
      state = StorageData(events);
      applyLimit = false;
      if (!req.storageOnly) {
        // Send request filter to relays
        send(req);
      }
    });

    final sub = ref.listen(storageNotifierProvider, (_, __) async {
      // Every time something gets saved in storage this triggers
      // and so we must re-issue the query
      state = StorageLoading(state.models);
      final events = await db.queryAsync(req, applyLimit: applyLimit);
      state = StorageData(events);
    });

    ref.onDispose(() {
      sub.close();
    });
  }

  Future<void> save(List<Event> events) async {
    // delegate to storagenotifier
  }

  @override
  void send(RequestFilter req) async {
    // no-op as dummy storage does not hit relays
  }
}

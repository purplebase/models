import 'dart:async';

import 'package:faker/faker.dart';
import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';

final _dummySigner = DummySigner();

/// Reactive storage with dummy data, singleton
class DummyStorageNotifier extends StorageNotifier {
  final Ref ref;
  final List<Event> _events = [];
  var applyLimit = true;

  static DummyStorageNotifier? _instance;

  factory DummyStorageNotifier(Ref ref) {
    return _instance ??= DummyStorageNotifier._internal(ref);
  }

  DummyStorageNotifier._internal(this.ref) {
    // Pre-populate database from provider,
    // happens once as this is a singleton
    save(ref.read(seedDummyDataProvider));
  }

  @override
  Future<void> save(Iterable<Event> events) async {
    for (final event in events) {
      _events.add(event);
    }
    state = StorageSignal(events);
  }

  @override
  Future<List<Event>> queryAsync(RequestFilter req,
      {bool applyLimit = true, Iterable<Event>? onModels}) async {
    return query(req, applyLimit: applyLimit);
  }

  @override
  List<Event> query(RequestFilter req,
      {bool applyLimit = true, Iterable<Event>? onModels}) {
    List<Event> results;
    // If `onModels` present then apply req on those, otherwise on all stored ones
    final models = onModels?.toList() ?? _events;

    if (req.ids.isNotEmpty) {
      results = models.where((e) => req.ids.contains(e.id)).toList();
    } else {
      results = models;
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
    _events.removeWhere((e) => events.contains(e));
  }

  Future<void> generateDummyFor(
      {required String pubkey,
      required int kind,
      int amount = 10,
      bool stream = false}) async {
    await Future.delayed(Duration(seconds: 1));

    var profile = query(RequestFilter(authors: {pubkey}, kinds: {0}))
        .cast<Profile>()
        .firstOrNull;

    profile ??= await PartialProfile(
            name: faker.person.name(),
            nip05: faker.internet.freeEmail(),
            pictureUrl: faker.internet.httpsUrl())
        .signWith(_dummySigner, withPubkey: pubkey);

    final models = [
      for (final _ in List.generate(amount, (_) {}))
        await PartialNote(faker.lorem.sentence())
            .signWith(_dummySigner, withPubkey: profile.pubkey),
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
                .signWith(_dummySigner, withPubkey: profile!.pubkey),
          ];
          await save(models);
        }
      } else {
        t.cancel();
      }
    });
  }
}

class DummyRequestNotifier extends RequestNotifier {
  DummyRequestNotifier(super.ref, super.req);

  @override
  void send(RequestFilter req) async {
    // no-op as dummy storage does not hit relays
  }
}

final seedDummyDataProvider = StateProvider<List<Event>>((_) => []);

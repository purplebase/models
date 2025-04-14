import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:faker/faker.dart';
import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';

/// Reactive storage with dummy data, singleton
class DummyStorageNotifier extends StorageNotifier {
  final Ref ref;
  final Set<Event> _events = {};
  var applyLimit = true;

  static DummyStorageNotifier? _instance;

  factory DummyStorageNotifier(Ref ref) {
    return _instance ??= DummyStorageNotifier._internal(ref);
  }

  DummyStorageNotifier._internal(this.ref);

  final Map<RequestFilter, Timer> _timers = {};

  @override
  Future<void> initialize(StorageConfiguration config) async {
    await super.initialize(config);
  }

  @override
  Future<void> save(Set<Event> events,
      {String? relayGroup, bool publish = true}) async {
    _events.addAll(events);

    // Empty response metadata as these events do not come from a relay
    final responseMetadata = ResponseMetadata(relayUrls: {});
    if (mounted) {
      state = (({for (final e in events) e.id}, responseMetadata));
    }
  }

  @override
  Future<List<Event>> query(RequestFilter req,
      {bool applyLimit = true, Set<String>? onIds}) async {
    return _querySync(req, applyLimit: applyLimit);
  }

  List<Event> _querySync(RequestFilter req,
      {bool applyLimit = true, Set<String>? onIds}) {
    List<Event> results;
    // If onIds present then restrict req to those
    if (onIds != null) {
      req = req.copyWith(ids: onIds);
    }

    if (req.ids.isNotEmpty) {
      results = _events.where((e) => req.ids.contains(e.id)).toList();
    } else {
      results = _events.toList();
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

    return results.toList();
  }

  @override
  Future<void> clear([RequestFilter? req]) async {
    if (req == null) {
      _events.clear();
      return;
    }
    final events = await query(req);
    _events.removeWhere((e) => events.contains(e));
  }

  final _random = Random();

  @override
  Future<void> send(RequestFilter req) async {
    final preEoseAmount = req.limit ?? req.queryLimit ?? 10;
    var streamAmount = (req.queryLimit ?? 10) - preEoseAmount;

    if (req.kinds.isEmpty || req.kinds.first == 7 || req.kinds.first == 9735) {
      return;
    }
    final pubkey = req.authors.firstOrNull;
    final profiles = pubkey != null
        ? [generateProfile(pubkey)]
        : List.generate(10, (i) => generateProfile());

    final models = List.generate(preEoseAmount, (i) {
      return generateEvent(
          kind: req.kinds.first,
          pubkey: profiles[_random.nextInt(profiles.length)].pubkey,
          createdAt:
              DateTime.now().subtract(Duration(minutes: _random.nextInt(10))));
    }).nonNulls.toSet();

    final andModels = [
      if (req.and != null)
        for (final m in models)
          for (final r in req.and!(m))
            ...List.generate(
              _random.nextInt(20),
              (i) => generateEvent(
                kind: r.req!.kinds.first,
                pubkey: profiles[_random.nextInt(profiles.length)].pubkey,
                parentId: m.id,
              ),
            ).nonNulls.toSet()
    ];
    Future.microtask(() {
      save({...profiles, ...models, ...andModels});
    });

    if (streamAmount > 0) {
      await Future.delayed(Duration(seconds: 2));
      _timers[req] = Timer.periodic(config.streamingBufferWindow, (t) async {
        if (mounted) {
          print('in mounted tick');
          if (streamAmount == 0) {
            t.cancel();
            _timers.remove(req);
          } else {
            final models = List.generate(
              (streamAmount < 5 ? streamAmount : 5),
              (i) {
                streamAmount--;
                return generateEvent(
                    kind: req.kinds.first,
                    pubkey: profiles[_random.nextInt(profiles.length)].pubkey);
              },
            ).nonNulls.toSet();

            final andModels = [
              if (req.and != null)
                for (final m in models)
                  for (final r in req.and!(m))
                    ...List.generate(
                      _random.nextInt(20),
                      (i) {
                        return generateEvent(
                          kind: r.req!.kinds.first,
                          pubkey:
                              profiles[_random.nextInt(profiles.length)].pubkey,
                          parentId: m.id,
                        );
                      },
                    ).nonNulls.toSet()
            ];
            Future.microtask(() {
              save({...models, ...andModels});
            });
          }
        } else {
          t.cancel();
          _timers.remove(req);
        }
      });
    }
  }

  @override
  Future<void> cancel(RequestFilter req) async {
    _timers[req]?.cancel();
  }

  Profile generateProfile([String? pubkey]) {
    return PartialProfile(
            name: faker.person.name(),
            nip05: faker.internet.freeEmail(),
            pictureUrl: faker.internet.httpsUrl())
        .dummySign(pubkey);
  }

  Event? generateEvent(
      {required int kind,
      String? parentId,
      String? pubkey,
      DateTime? createdAt}) {
    return switch (kind) {
      0 => generateProfile(),
      1 => PartialNote(faker.lorem.sentence(), createdAt: createdAt)
          .dummySign(pubkey),
      7 => parentId == null
          ? null
          : (PartialReaction()..internal.addTag('e', [parentId])).dummySign(),
      9 => PartialChatMessage(faker.lorem.sentence()).dummySign(pubkey),
      9735 => pubkey != null && parentId != null
          ? Zap.fromMap(
              jsonDecode(
                  _sampleBolt11(zapperPubkey: pubkey, eventId: parentId)),
              ref)
          : null,
      _ => null,
    };
  }
}

_sampleBolt11({required String zapperPubkey, required String eventId}) => '''
{
        "content": "✨",
        "created_at": ${DateTime.now().millisecondsSinceEpoch ~/ 1000},
        "id": "${generate64Hex()}",
        "kind": 9735,
        "pubkey": "79f00d3f5a19ec806189fcab03c1be4ff81d18ee4f653c88fac41fe03570f432",
        "tags": [
            [
                "p",
                "20651ab8c2fb1febca56b80deba14630af452bdce64fe8f04a9f5f67e4a3c1cc"
            ],
            [
                "e",
                "$eventId"
            ],
            [
                "P",
                "$zapperPubkey"
            ],
            [
                "bolt11",
                "lnbc210n1pnl48jjxqrrsspqqsqqdpvta04q5jff4q5ch6ffe2y25jwg9x97j2w2e85js69ta0s29da748s3yt4frxt8t4z62h3l3g2dlu6tynlefsjffdhn45dr84h3my9h4t7ety4s7awnlkl89p26tkq4jkc3z54ufjmwg96ddjtk7spnl55zu"
            ],
            [
                "preimage",
                "986393670e035a9c131353a796fc2a0fb9f09e6112ca3c89a4f00f9dd2356afb"
            ],
            [
                "description",
                "{\\"id\\":\\"50dd637e30455a6dd6e1c9159c58b2cba31c75df29a5806162b813b3d93fe13d\\",\\"sig\\":\\"b86c1e09139e0367d9ed985beb14995efb3025eb68c8a56045ce2a2a35639d8f4187acae78c022532801fb068cf3560dcab12497f6d2a9376978c9bde35b15cd\\",\\"pubkey\\":\\"97f848adcc4c6276685fe48426de5614887c8a51ada0468cec71fba938272911\\",\\"created_at\\":1744474327,\\"kind\\":9734,\\"tags\\":[[\\"relays\\",\\"wss://relay.primal.net\\",\\"wss://relay-nwc-dev.rizful.com/v1\\",\\"wss://relay.snort.social\\",\\"wss://relay.nostr.band\\",\\"wss://slick.mjex.me\\",\\"wss://nostr.wine\\",\\"wss://nfnitloop.com/nostr\\",\\"wss://relay.damus.io\\",\\"wss://eden.nostr.land\\",\\"wss://nos.lol\\",\\"wss://nostr.8777.ch\\",\\"wss://nostr.land\\",\\"ws://209.122.211.18:4848\\",\\"wss://unhostedwallet.com\\",\\"wss://filter.nostr.wine?global=all\\"],[\\"amount\\",\\"21000\\"],[\\"lnurl\\",\\"lnurl1dp68gurn8ghj7em9w3skccne9e3k7mf09emk2mrv944kummhdchkcmn4wfk8qtm2v4nxj7n6d3jsyutkku\\"],[\\"p\\",\\"20651ab8c2fb1febca56b80deba14630af452bdce64fe8f04a9f5f67e4a3c1cc\\"],[\\"e\\",\\"7abbce7aa0c5cd430efd627bbe5b5908de48db5cec5742f694befe38b34bce9f\\"]],\\"content\\":\\"✨\\"}"
            ]
        ]
    }
''';

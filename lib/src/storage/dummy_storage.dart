part of models;

/// Reactive storage with dummy data, singleton
class DummyStorageNotifier extends StorageNotifier {
  final Ref ref;
  final Set<Model> _models = {};
  var applyLimit = true;

  static DummyStorageNotifier? _instance;

  factory DummyStorageNotifier(Ref ref) {
    return _instance ??= DummyStorageNotifier._(ref);
  }

  DummyStorageNotifier._(this.ref);

  final Map<RequestFilter, Timer> _timers = {};

  @override
  Future<void> initialize(StorageConfiguration config) async {
    await super.initialize(config);
  }

  @override
  Future<void> save(Set<Model> models,
      {String? relayGroup, bool publish = false}) async {
    // Publish in the background, before using metadata/transformMap
    if (publish && models.isNotEmpty) {
      final relayUrls =
          config.getRelays(relayGroup: relayGroup, useDefault: true);
      for (final relayUrl in relayUrls) {
        print('Fake publishing ${models.length} models to $relayUrl');
      }
    }

    for (final model in models) {
      // Need to deconstruct to inject metadata and
      // remove useless content, then construct again
      final metadata = await model.processMetadata();
      final transformedModel = model.transformMap(model.toMap());
      final constructor = Model.getConstructorForKind(model.event.kind);
      final e = constructor!.call(
          {...transformedModel, if (metadata.isNotEmpty) 'metadata': metadata},
          ref) as Model;
      if (e is ReplaceableModel) {
        _models.removeWhere((m) => m.id == e.id);
      }
      _models.add(e);
    }

    // Empty response metadata as these models do not come from a relay
    final responseMetadata = ResponseMetadata(relayUrls: {});
    if (mounted) {
      state = (({for (final e in models) e.id}, responseMetadata));
    }
  }

  @override
  Future<List<E>> query<E extends Model<dynamic>>(RequestFilter<E> req,
      {bool applyLimit = true, Set<String>? onIds}) async {
    final results = querySync<E>(req, applyLimit: applyLimit, onIds: onIds);
    return Future.microtask(() {
      // No queryLimit disables streaming
      final fetched = fetchSync<E>(req.copyWith(queryLimit: null));
      return [...results, ...fetched];
    });
  }

  /// [onModels] is an extension in this implementation
  /// that allows filtering req on a specific set of models (other than _models)
  @override
  List<E> querySync<E extends Model<dynamic>>(RequestFilter<E> req,
      {bool applyLimit = true, Set<String>? onIds, Set<Model>? onModels}) {
    // Results is of Model<dynamic>, but it will be casted once we have results of the right kind
    List<Model> results = (onModels ?? _models).toList();

    // If onIds present then restrict req to those
    if (onIds != null) {
      req = req.copyWith(ids: onIds);
    }

    final replaceableIds = req.ids.where(kReplaceableRegexp.hasMatch);
    final regularIds = {...req.ids}..removeAll(replaceableIds);

    if (regularIds.isNotEmpty) {
      results = results.where((e) => regularIds.contains(e.id)).toList();
    }

    if (replaceableIds.isNotEmpty) {
      results = [
        ...results,
        ...results.where((e) {
          return e is ReplaceableModel &&
              replaceableIds.contains(e.event.addressableId);
        })
      ];
    }

    if (req.authors.isNotEmpty) {
      results =
          results.where((m) => req.authors.contains(m.event.pubkey)).toList();
    }

    if (req.kinds.isNotEmpty) {
      results = results.where((m) => req.kinds.contains(m.event.kind)).toList();
    }

    if (req.since != null) {
      results =
          results.where((m) => m.event.createdAt.isAfter(req.since!)).toList();
    }

    if (req.until != null) {
      results =
          results.where((m) => m.event.createdAt.isBefore(req.until!)).toList();
    }

    if (req.tags.isNotEmpty) {
      results = results.where((m) {
        // Requested tags should behave like AND: use fold with initial true and acc &&
        return req.tags.entries.fold(true, (acc, entry) {
          final wantedTagKey = entry.key.substring(1); // remove leading '#'
          final wantedTagValues = entry.value;
          // Event tags should behave like OR: use fold with initial false and acc ||
          return acc &&
              m.event.getTagSetValues(wantedTagKey).fold(false,
                  (acc, currentTagValue) {
                return acc || wantedTagValues.contains(currentTagValue);
              });
        });
      }).toList();
    }

    results.sort((a, b) => b.event.createdAt.compareTo(a.event.createdAt));

    if (applyLimit && req.limit != null && results.length > req.limit!) {
      results = results.sublist(0, req.limit!);
    }

    if (req.where != null) {
      results = results.where(req.where!).toList();
    }

    return results.cast<E>();
  }

  @override
  Future<void> clear([RequestFilter? req]) async {
    if (req == null) {
      _models.clear();
      return;
    }
    final models = await query(req);
    _models.removeWhere((e) => models.contains(e));
  }

  @override
  Future<void> cancel([RequestFilter? req]) async {
    if (req == null) {
      for (final t in _timers.values) {
        t.cancel();
      }
    }
    _timers[req]?.cancel();
  }

  // Dummy model generation

  final _random = Random();

  @override
  Future<Set<E>> fetch<E extends Model<dynamic>>(RequestFilter<E> req) async {
    return fetchSync(req);
  }

  Set<E> fetchSync<E extends Model<dynamic>>(RequestFilter<E> req) {
    if (!req.remote) return {};

    final preEoseAmount = req.limit ?? req.queryLimit ?? 10;
    var streamAmount =
        req.queryLimit != null ? req.queryLimit! - preEoseAmount : 0;

    if (req.kinds.isEmpty || req.kinds.first == 7 || req.kinds.first == 9735) {
      return {};
    }
    final profiles = req.authors.isNotEmpty
        ? req.authors.map(generateProfile).toList()
        : List.generate(10, (i) => generateProfile());
    // Add already saved profiles
    profiles.addAll(querySync(RequestFilter<Profile>()));

    final follows = <Profile>{};
    if (req.kinds.contains(3)) {
      follows.addAll(List.generate(10, (i) => generateProfile()));
    }

    final baseModels = List.generate(preEoseAmount, (i) {
      final profile = profiles.firstWhereOrNull(
              (p) => p.pubkey == req.authors.shuffled().firstOrNull) ??
          profiles[_random.nextInt(profiles.length)];

      return generateModel(
        kind: req.kinds.first,
        pubkey: profile.pubkey,
        createdAt:
            DateTime.now().subtract(Duration(minutes: _random.nextInt(10))),
        pTags: follows.map((e) => e.event.pubkey).toList(),
      );
    }).nonNulls.toSet();

    final andModels = [
      if (req.and != null)
        for (final m in baseModels)
          for (final r in req.and!(m))
            ...List.generate(
              _random.nextInt(20),
              (i) => generateModel(
                kind: r.req!.kinds.first,
                pubkey: profiles[_random.nextInt(profiles.length)].pubkey,
                parentId: m.id,
              ),
            ).nonNulls.toSet()
    ];

    final models = {...profiles, ...follows, ...baseModels, ...andModels};
    Future.microtask(() => save(models));

    if (streamAmount > 0) {
      () {
        _timers[req] = Timer.periodic(config.streamingBufferWindow, (t) async {
          if (mounted) {
            if (streamAmount == 0) {
              t.cancel();
              _timers.remove(req);
            } else {
              final amt = streamAmount < 5 ? streamAmount : 5;
              final baseModels = List.generate(
                amt,
                (i) {
                  streamAmount--;
                  return generateModel(
                      kind: req.kinds.first,
                      pubkey:
                          profiles[_random.nextInt(profiles.length)].pubkey);
                },
              ).nonNulls.toSet();

              final andModels = [
                if (req.and != null)
                  for (final m in baseModels)
                    for (final r in req.and!(m))
                      ...List.generate(
                        _random.nextInt(20),
                        (i) {
                          return generateModel(
                            kind: r.req!.kinds.first,
                            pubkey: profiles[_random.nextInt(profiles.length)]
                                .pubkey,
                            parentId: m.id,
                          );
                        },
                      ).nonNulls.toSet()
              ];
              Future.microtask(() {
                save({...baseModels, ...andModels});
              });
            }
          } else {
            t.cancel();
            _timers.remove(req);
          }
        });
      }();
    }
    return querySync(req.copyWith(remote: false), onModels: models).toSet();
  }

  Profile generateProfile([String? pubkey]) {
    return PartialProfile(
            name: faker.person.name(),
            nip05: faker.internet.freeEmail(),
            pictureUrl: faker.internet.httpsUrl())
        .dummySign(pubkey);
  }

  Model? generateModel(
      {required int kind,
      String? parentId,
      String? pubkey,
      DateTime? createdAt,
      List<String> pTags = const []}) {
    return switch (kind) {
      0 => generateProfile(),
      3 => PartialContactList(followPubkeys: pTags).dummySign(pubkey),
      1 => PartialNote(faker.lorem.sentence(), createdAt: createdAt)
          .dummySign(pubkey),
      7 => parentId == null
          ? null
          : (PartialReaction()..event.addTag('e', [parentId])).dummySign(),
      9 => PartialChatMessage(faker.lorem.sentence()).dummySign(pubkey),
      9735 => pubkey != null && parentId != null
          ? Zap.fromMap(
              _sampleZap(zapperPubkey: pubkey, eventId: parentId), ref)
          : null,
      _ => null,
    };
  }
}

_sampleZap({required String zapperPubkey, required String eventId}) =>
    jsonDecode('''
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
''');

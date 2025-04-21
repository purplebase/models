part of models;

/// Reactive storage with dummy data, singleton
class DummyStorageNotifier extends StorageNotifier {
  final Ref ref;
  Set<Model> _models = {};
  var applyLimit = true;

  static DummyStorageNotifier? _instance;

  factory DummyStorageNotifier(Ref ref) {
    return _instance ??= DummyStorageNotifier._(ref);
  }

  DummyStorageNotifier._(this.ref);

  final Map<RequestFilter, Timer> _timers = {};

  final _queriedModels = <int, Set<String>>{};

  @override
  Future<void> initialize(StorageConfiguration config) async {
    await super.initialize(config);
    _queriedModels.clear();
  }

  @override
  Future<void> save(Set<Model<dynamic>> models,
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
      // Need to deconstruct to remove useless content, then construct again
      final transformedModel = model.transformMap(model.toMap());
      final constructor = Model.getConstructorForKind(model.event.kind);
      final e = constructor!.call({
        ...transformedModel,
        // Need to pass metadata back
        if (model.event.metadata.isNotEmpty) 'metadata': model.event.metadata
      }, ref) as Model;
      if (e is ReplaceableModel) {
        _models.removeWhere((m) => m.id == e.id);
      }
      _models.add(e);
    }

    // FIFO queue, ensure we don't go over config.maxModels
    if (_models.length > config.maxModels) {
      _models = _models.sortByCreatedAt().take(config.maxModels).toSet();
    }

    if (mounted) {
      state = {for (final e in models) e.id};
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

  /// that allows filtering req on a specific set of models (other than _models)
  @override
  List<E> querySync<E extends Model<dynamic>>(RequestFilter<E> req,
      {bool applyLimit = true, Set<String>? onIds}) {
    // Results is of Model<dynamic>, but it will be casted once we have results of the right kind
    List<Model> results = _models.toList();

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

  @override
  Future<Set<E>> fetch<E extends Model<dynamic>>(RequestFilter<E> req) async {
    return fetchSync(req);
  }

  Set<E> fetchSync<E extends Model<dynamic>>(RequestFilter<E> req) {
    if (!req.remote) return {};

    final preEoseAmount = req.limit ?? req.queryLimit ?? 10;
    var streamAmount =
        req.queryLimit != null ? req.queryLimit! - preEoseAmount : 0;

    if (streamAmount > 0) {
      () {
        _timers[req] = Timer.periodic(config.streamingBufferWindow, (t) async {
          if (mounted) {
            if (streamAmount == 0) {
              t.cancel();
              _timers.remove(req);
            } else {
              final kind = req.kinds.first;
              _queriedModels[kind] ??= {};
              final amt = streamAmount < 5 ? streamAmount : 5;
              final models = _models
                  .where((m) =>
                      m.event.kind == kind &&
                      !_queriedModels[kind]!.contains(m.id))
                  .shuffled()
                  .take(amt)
                  .map((m) {
                final map = m.toMap();
                map['created_at'] =
                    DateTime.now().millisecondsSinceEpoch ~/ 1000;
                return Model.getConstructorForKind(map['kind'])!.call(map, ref);
              });
              final ids = models.map((m) => m.id);
              _queriedModels[kind]!.addAll(ids);
              streamAmount = streamAmount - models.length;

              // Since ids of manipulated models remain the same, need to remove from set
              _models.removeAll(models);
              await save(models.toSet());
            }
          } else {
            t.cancel();
            _timers.remove(req);
          }
        });
      }();
    }

    final models =
        querySync(req.copyWith(remote: false, limit: preEoseAmount)).toSet();
    _queriedModels[req.kinds.first] ??= {};
    _queriedModels[req.kinds.first]!.addAll(models.map((m) => m.id));
    return models;
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
    pubkey ??= Utils.generateRandomHex64();
    return switch (kind) {
      0 => generateProfile(),
      3 => PartialContactList(followPubkeys: pTags).dummySign(pubkey),
      1 => PartialNote(faker.lorem.sentence(), createdAt: createdAt)
          .dummySign(pubkey),
      7 => parentId == null
          ? null
          : (PartialReaction()..event.addTag('e', [parentId])).dummySign(),
      9 => PartialChatMessage(faker.lorem.sentence()).dummySign(pubkey),
      9735 => parentId != null
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
        "id": "${Utils.generateRandomHex64()}",
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

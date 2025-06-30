part of models;

/// Reactive storage with dummy data, singleton
class DummyStorageNotifier extends StorageNotifier {
  final Ref ref;
  Set<Model> _models = {};

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
  Future<bool> save(Set<Model<dynamic>> models) async {
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
    if (_models.length > config.keepMaxModels) {
      _models = _models.sortByCreatedAt().take(config.keepMaxModels).toSet();
    }

    if (mounted && models.isNotEmpty) {
      // TODO: Request is empty
      state = InternalStorageData(
          req: Request([]), updatedIds: {for (final e in models) e.id});
    }

    return true;
  }

  @override
  Future<PublishResponse> publish(Set<Model<dynamic>> models,
      {Source source = const RemoteSource()}) async {
    final response = PublishResponse();
    // Publish in the background, before using metadata/transformMap
    if (models.isNotEmpty) {
      final relayUrls = config.getRelays(source: source, useDefault: true);
      for (final relayUrl in relayUrls) {
        final message = 'Fake publishing ${models.length} models to $relayUrl';
        for (final model in models) {
          response.addEvent(model.event.id,
              relayUrl: relayUrl, accepted: true, message: message);
        }
      }
    }
    return response;
  }

  @override
  Future<List<E>> query<E extends Model<dynamic>>(Request<E> req,
      {Source source = const RemoteSource()}) async {
    List<E> allResults = querySync(req);

    return Future.microtask(() async {
      final fetched = _fetch<E>(req);
      final filteredResults = allResults.whereType<E>().toList();
      return [...filteredResults, ...fetched];
    });
  }

  @override
  List<E> querySync<E extends Model<dynamic>>(Request<E> req) {
    List<E> allResults = [];
    for (var filter in req.filters) {
      // Results is of Model<dynamic> (as it starts with the complete _models database),
      // it will be casted once we have results of the right kind
      List<Model> results = _models.toList();

      final replaceableIds = filter.ids.where(_kReplaceableRegexp.hasMatch);
      final regularIds = {...filter.ids}..removeAll(replaceableIds);

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

      if (filter.authors.isNotEmpty) {
        results = results
            .where((m) => filter.authors.contains(m.event.pubkey))
            .toList();
      }

      if (filter.kinds.isNotEmpty) {
        results =
            results.where((m) => filter.kinds.contains(m.event.kind)).toList();
      }

      if (filter.since != null) {
        results = results
            .where((m) => m.event.createdAt.isAfter(filter.since!))
            .toList();
      }

      if (filter.until != null) {
        results = results
            .where((m) => m.event.createdAt.isBefore(filter.until!))
            .toList();
      }

      if (filter.tags.isNotEmpty) {
        results = results.where((m) {
          // filteruested tags should behave like AND: use fold with initial true and acc &&
          return filter.tags.entries.fold(true, (acc, entry) {
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

      if (filter.limit != null && results.length > filter.limit!) {
        results = results.sublist(0, filter.limit!);
      }

      if (filter.where != null) {
        results = results.where((m) => filter.where!(m as E)).toList();
      }

      allResults.addAll(results.cast());
    }
    return allResults;
  }

  @override
  Future<void> clear([Request? req]) async {
    if (req == null) {
      _models.clear();
      return;
    }
    final models = await query(req);
    _models.removeWhere((e) => models.contains(e));
  }

  @override
  Future<void> cancel([Request? req]) async {
    if (req == null) {
      for (final t in _timers.values) {
        t.cancel();
      }
      return;
    }
    for (final filter in req.filters) {
      _timers[filter]?.cancel();
    }
  }

  /// Simulates a fetch, uses limit on the filters.
  /// Streaming emits in batches of 5, use [config.streamingBufferWindow]
  List<E> _fetch<E extends Model<dynamic>>(Request<E> req, {Source? source}) {
    if (source is LocalSource) return [];

    for (var filter in req.filters) {
      final queryLimit = (filter.limit ?? 10) * 2;
      var streamAmount = queryLimit - (filter.limit ?? 10);

      if (streamAmount > 0) {
        () {
          _timers[filter] =
              Timer.periodic(config.streamingBufferWindow, (t) async {
            if (mounted) {
              if (streamAmount == 0) {
                t.cancel();
                _timers.remove(filter);
              } else {
                final kind = filter.kinds.first;
                _queriedModels[kind] ??= {};
                final amt = streamAmount < 5 ? streamAmount : 5;
                // Grab models not queried yet and update their timestamp to now
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
                  return Model.getConstructorForKind(map['kind'])!
                      .call(map, ref);
                });
                final ids = models.map((m) => m.id);
                _queriedModels[kind]!.addAll(ids);
                streamAmount = streamAmount - models.length;

                // Since ids of manipulated models remain the same, need to remove from set
                // in order to add them back again
                _models.removeAll(models);
                await save(models.toSet());
              }
            } else {
              t.cancel();
              _timers.remove(filter);
            }
          });
        }();
      }
    }

    // Return empty list for LocalSource to avoid infinite recursion
    return [];
  }

  /// Generates a fake profile
  Profile generateProfile([String? pubkey]) {
    return PartialProfile(
            name: faker.person.name(),
            nip05: faker.internet.freeEmail(),
            pictureUrl: faker.internet.httpsUrl())
        .dummySign(pubkey);
  }

  /// Generates a fake model, supported kinds: 0, 1, 3, 7, 9735
  Model? generateModel(
      {required int kind,
      String? parentId,
      String? pubkey,
      DateTime? createdAt,
      Set<String> pTags = const {}}) {
    pubkey ??= Utils.generateRandomHex64();
    return switch (kind) {
      0 => generateProfile(),
      1 => PartialNote(faker.lorem.sentence(), createdAt: createdAt)
          .dummySign(pubkey),
      3 => PartialContactList(followPubkeys: pTags).dummySign(pubkey),
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

  /// Generate a feed with related models for [pubkey]
  void generateFeed([String? pubkey]) {
    pubkey ??= Utils.generateRandomHex64();
    final r = Random();
    // Only generate if storage is empty
    if (_models.isEmpty) {
      final profile = generateProfile(pubkey);
      // Assume we want to "sign in" this user when generating a dummy feed
      DummySigner(ref, pubkey: pubkey).initialize(active: true);

      final follows =
          List.generate(min(15, r.nextInt(50)), (i) => generateProfile());

      final contactList = generateModel(
        kind: 3,
        pubkey: profile.pubkey,
        pTags: follows.map((e) => e.event.pubkey).toSet(),
      )!;

      // 500 notes from random follows and their likes and zaps
      final models = <Model>{};
      List.generate(r.nextInt(500), (i) {
        final note = generateModel(
          kind: 1,
          pubkey: follows[r.nextInt(follows.length)].pubkey,
          createdAt: DateTime.now().subtract(
            Duration(minutes: r.nextInt(300)),
          ),
        )!;
        models.add(note);
        models.addAll(
          List.generate(r.nextInt(50), (i) {
            return generateModel(kind: 7, parentId: note.id)!;
          }),
        );
        models.addAll(
          List.generate(r.nextInt(10), (i) {
            return generateModel(kind: 9735, parentId: note.id)!;
          }),
        );
      });

      save({profile, ...follows, contactList, ...models});
    }
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

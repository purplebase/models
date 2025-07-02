part of models;

/// Reactive storage with dummy data using internal relay backend, singleton
class DummyStorageNotifier extends StorageNotifier {
  final Ref ref;
  late MemoryStorage _relayStorage;

  static DummyStorageNotifier? _instance;

  factory DummyStorageNotifier(Ref ref) {
    return _instance ??= DummyStorageNotifier._(ref);
  }

  DummyStorageNotifier._(this.ref);

  final Map<RequestFilter, Timer> _streamingTimers = {};
  final Map<RequestFilter, StreamSubscription> _streamingSubscriptions = {};
  final Set<String> _streamingRequestIds =
      {}; // Track which requests are streaming

  @override
  Future<void> initialize(StorageConfiguration config) async {
    await super.initialize(config);
    _relayStorage = MemoryStorage();

    // Only seed storage if it's empty (not during tests)
    if (_shouldSeedStorage()) {
      await _seedStorage();
    }
  }

  /// Determines if storage should be seeded with dummy data
  bool _shouldSeedStorage() {
    // Only seed if explicitly requested (not during tests)
    // Tests should start with empty storage for predictable results
    return false;
  }

  /// Seeds the storage with a realistic dataset during initialization
  Future<void> _seedStorage() async {
    final r = Random();
    final seededModels = <Model>{};

    // Generate 20-50 profiles
    final profiles =
        List.generate(20 + r.nextInt(30), (i) => generateProfile());
    seededModels.addAll(profiles);

    // Generate contact lists for some profiles
    for (int i = 0; i < profiles.length ~/ 3; i++) {
      final profile = profiles[i];
      final follows = profiles
          .where((p) => p.pubkey != profile.pubkey)
          .take(r.nextInt(15))
          .toSet();
      final contactList = generateModel(
        kind: 3,
        pubkey: profile.pubkey,
        pTags: follows.map((p) => p.pubkey).toSet(),
      );
      if (contactList != null) seededModels.add(contactList);
    }

    // Generate 200-500 notes with realistic timestamps (spread over last 7 days)
    final noteCount = 200 + r.nextInt(300);
    for (int i = 0; i < noteCount; i++) {
      final author = profiles[r.nextInt(profiles.length)];
      final createdAt = DateTime.now().subtract(Duration(
        minutes: r.nextInt(7 * 24 * 60), // Random time in last 7 days
      ));
      final note = generateModel(
        kind: 1,
        pubkey: author.pubkey,
        createdAt: createdAt,
      );
      if (note != null) {
        seededModels.add(note);

        // Add some reactions to notes (10% chance)
        if (r.nextDouble() < 0.1) {
          final reactions = List.generate(r.nextInt(20), (j) {
            final reactor = profiles[r.nextInt(profiles.length)];
            return generateModel(
                kind: 7, parentId: note.event.id, pubkey: reactor.pubkey);
          }).whereType<Model>();
          seededModels.addAll(reactions);
        }

        // Add some zaps to notes (5% chance)
        if (r.nextDouble() < 0.05) {
          final zaps = List.generate(r.nextInt(5), (j) {
            final zapper = profiles[r.nextInt(profiles.length)];
            return generateModel(
                kind: 9735, parentId: note.event.id, pubkey: zapper.pubkey);
          }).whereType<Model>();
          seededModels.addAll(zaps);
        }
      }
    }

    // Store all seeded data
    await _storeToRelay(seededModels);
  }

  /// Stores models in relay storage
  Future<void> _storeToRelay(Iterable<Model<dynamic>> models) async {
    for (final model in models) {
      _relayStorage.storeEvent(model.event.toMap());
    }
  }

  @override
  Future<bool> save(Set<Model<dynamic>> models) async {
    // Store in relay storage
    await _storeToRelay(models);

    if (mounted && models.isNotEmpty) {
      state = InternalStorageData(
          req: Request([]), updatedIds: {for (final e in models) e.event.id});
    }

    return true;
  }

  @override
  Future<PublishResponse> publish(Set<Model<dynamic>> models,
      {Source source = const RemoteSource()}) async {
    final response = PublishResponse();

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
    // Always start with local results
    List<E> results = querySync(req);

    // For LocalSource, return only local results
    if (source is LocalSource) {
      return results;
    }

    // For RemoteSource, handle streaming if enabled
    if (source is RemoteSource && source.stream) {
      // Mark this request as streaming (remove limits for future queries)
      final requestId = req.toString();
      _streamingRequestIds.add(requestId);

      // Start streaming simulation for each filter
      for (final filter in req.filters) {
        _startStreamingForFilter(filter, source);
      }
    }

    return results;
  }

  @override
  List<E> querySync<E extends Model<dynamic>>(Request<E> req) {
    final allResults = <E>[];
    final requestId = req.toString();
    final isStreaming = _streamingRequestIds.contains(requestId);

    for (final filter in req.filters) {
      // Handle replaceable IDs by converting them to regular filters
      final replaceableIds = filter.ids.where((id) => id.contains(':')).toSet();
      final regularIds = filter.ids.difference(replaceableIds);

      List<E> results = [];

      // Query for regular IDs
      if (regularIds.isNotEmpty || filter.ids.isEmpty) {
        final regularFilter = filter.copyWith(ids: regularIds);
        // Remove limit from filter since we'll apply it manually
        final filterNoLimit = regularFilter.copyWith(limit: null);
        final relayEvents = _relayStorage.queryEvents([filterNoLimit]);

        final models = relayEvents
            .map((event) {
              final constructor = Model.getConstructorForKind(event['kind']);
              if (constructor == null) return null;
              return constructor(event, ref) as Model;
            })
            .whereType<E>()
            .toList();

        results.addAll(models);
      }

      // Query for replaceable IDs (these are addressable IDs, not event IDs)
      if (replaceableIds.isNotEmpty) {
        for (final addressableId in replaceableIds) {
          // Parse addressable ID to get kind, pubkey, and d-tag
          final parts = addressableId.split(':');
          if (parts.length >= 3) {
            final kind = int.tryParse(parts[0]);
            final pubkey = parts[1];
            final dTag = parts.length > 3 ? parts[3] : '';

            if (kind != null) {
              final replaceableFilter = RequestFilter(
                kinds: {kind},
                authors: {pubkey},
                tags: dTag.isNotEmpty
                    ? {
                        '#d': {dTag}
                      }
                    : null,
              );

              final events = _relayStorage.queryEvents([replaceableFilter]);
              final models = events
                  .map((event) {
                    final constructor =
                        Model.getConstructorForKind(event['kind']);
                    if (constructor == null) return null;
                    return constructor(event, ref) as Model;
                  })
                  .whereType<E>()
                  .toList();

              results.addAll(models);
            }
          }
        }
      }

      // Apply custom where clause if present
      if (filter.where != null) {
        results = results.where((m) => filter.where!(m)).toList();
      }

      // Sort and apply limit per filter
      if (results.isNotEmpty) {
        // Sort by created_at descending, then by id ascending for ties (Nostr standard)
        results.sort((a, b) {
          final timeComparison = b.event.createdAt.compareTo(a.event.createdAt);
          if (timeComparison != 0) return timeComparison;
          return a.event.id.compareTo(b.event.id);
        });

        // Apply limit if specified and not streaming
        if (!isStreaming &&
            filter.limit != null &&
            results.length > filter.limit!) {
          results = results.take(filter.limit!).toList();
        }
      }

      allResults.addAll(results);
    }

    // Remove duplicates while preserving order
    final seenIds = <String>{};
    final finalResults = allResults.where((model) {
      if (seenIds.contains(model.event.id)) return false;
      seenIds.add(model.event.id);
      return true;
    }).toList();

    return finalResults;
  }

  /// Starts streaming simulation for a specific filter
  void _startStreamingForFilter(RequestFilter filter, RemoteSource source) {
    // Cancel existing streaming for this filter
    _streamingTimers[filter]?.cancel();
    _streamingSubscriptions[filter]?.cancel();

    // For tests (when streamingBufferWindow is Duration.zero),
    // simulate streaming with immediate single model additions
    if (config.streamingBufferWindow == Duration.zero) {
      // Schedule small incremental additions for test predictability
      _simulateTestStreaming(filter);
      return;
    }

    // Generate new events periodically that match the filter
    _streamingTimers[filter] =
        Timer.periodic(config.streamingBufferWindow, (timer) async {
      if (!mounted) {
        timer.cancel();
        _streamingTimers.remove(filter);
        return;
      }

      final r = Random();
      // 30% chance to generate a new event each interval
      if (r.nextDouble() < 0.3) {
        final newModels = <Model>{};

        // Generate 1-3 new events that match the filter
        final eventCount = 1 + r.nextInt(3);
        for (int i = 0; i < eventCount; i++) {
          final model = _generateModelMatchingFilter(filter);
          if (model != null) {
            newModels.add(model);
          }
        }

        if (newModels.isNotEmpty) {
          await save(newModels);
        }
      }
    });
  }

  /// Simulates streaming for tests by adding models with delays
  void _simulateTestStreaming(RequestFilter filter) {
    int addedCount = 0;
    const maxAdds = 5; // Limit additions for predictable tests

    Timer.periodic(Duration(milliseconds: 100), (timer) async {
      if (!mounted || addedCount >= maxAdds) {
        timer.cancel();
        return;
      }

      // Generate a model with a newer timestamp to ensure it appears in results
      final baseModel = _generateModelMatchingFilter(filter);
      if (baseModel != null) {
        // Create a new model with a newer timestamp by calling the generator directly
        final newerTimestamp =
            DateTime.now().add(Duration(seconds: addedCount + 1));

        // Find the right pubkey from the filter
        final pubkey = filter.authors.isNotEmpty
            ? filter.authors.first
            : baseModel.event.pubkey;

        final newerModel = generateModel(
          kind: baseModel.event.kind,
          pubkey: pubkey,
          createdAt: newerTimestamp,
        );

        if (newerModel != null) {
          await save({newerModel});
          addedCount++;
        }
      }
    });
  }

  /// Generates a new model that would match the given filter
  Model? _generateModelMatchingFilter(RequestFilter filter) {
    final r = Random();

    // Pick a kind from the filter, or use a common kind
    final kinds = filter.kinds.isNotEmpty ? filter.kinds : {1, 7, 9735};
    final kind = kinds.elementAt(r.nextInt(kinds.length));

    // Pick an author from the filter, or generate random
    String? pubkey;
    if (filter.authors.isNotEmpty) {
      pubkey = filter.authors.elementAt(r.nextInt(filter.authors.length));
    }

    return generateModel(
      kind: kind,
      pubkey: pubkey,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> clear([Request? req]) async {
    if (req == null) {
      _relayStorage.clear();
      return;
    }

    // Query matching events and remove them by clearing and re-adding others
    final modelsToRemove = querySync(req).toSet();
    final allEvents = _relayStorage.queryEvents([RequestFilter()]);
    final eventsToKeep = allEvents.where((event) {
      final constructor = Model.getConstructorForKind(event['kind']);
      if (constructor == null) return true;
      final model = constructor(event, ref) as Model;
      return !modelsToRemove.contains(model);
    }).toList();

    // Clear and re-add events we want to keep
    _relayStorage.clear();
    for (final event in eventsToKeep) {
      _relayStorage.storeEvent(event);
    }
  }

  @override
  Future<void> cancel([Request? req]) async {
    if (req == null) {
      for (final timer in _streamingTimers.values) {
        timer.cancel();
      }
      for (final sub in _streamingSubscriptions.values) {
        sub.cancel();
      }
      _streamingTimers.clear();
      _streamingSubscriptions.clear();
      return;
    }

    for (final filter in req.filters) {
      _streamingTimers[filter]?.cancel();
      _streamingTimers.remove(filter);
      _streamingSubscriptions[filter]?.cancel();
      _streamingSubscriptions.remove(filter);
    }
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

  /// Generate a feed with related models for [pubkey] (backwards compatibility)
  void generateFeed([String? pubkey]) {
    // For backwards compatibility, but the new implementation seeds automatically
    print(
        'generateFeed() called - data is now seeded automatically during initialize()');
  }
}

_sampleZap({required String zapperPubkey, required String eventId}) =>
    jsonDecode('''
{
        "content": "✨",
        "created_at": ${DateTime.now().millisecondsSinceEpoch ~/ 1000},
        "id": "${Utils.generateRandomHex64()}",
        "kind": 9735,
        "pubkey": "79f00d3f5a19ec806189fcab03c1be4ff81d18ee4f653c88fac41fe8f04a9f5f67e4a3c1cc",
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
                                 "{\\"id\\":\\"50dd637e30455a6dd6e1c9159c58b2cba31c75df29a5806162b813b3d93fe13d\\",\\"sig\\":\\"b86c1e09139e0367d9ed985beb14995efb3025eb68c8a56045ce2a2a35639d8f4187acae78c022532801fb068cf3560dcab12497f6d2a9376978c9bde35b15cd\\",\\"pubkey\\":\\"97f848adcc4c6276685fe48426de5614887c8a51ada0468cec71fba938272911\\",\\"created_at\\":1744474327,\\"kind\\":9734,\\"tags\\":[[\\"relays\\",\\"wss://relay.primal.net\\"],[\\"amount\\",\\"21000\\"],[\\"p\\",\\"20651ab8c2fb1febca56b80deba14630af452bdce64fe8f04a9f5f67e4a3c1cc\\"],[\\"e\\",\\"7abbce7aa0c5cd430efd627bbe5b5908de48db5cec5742f694befe38b34bce9f\\"]],\\"content\\":\\"✨\\"}"
            ]
        ]
    }
''');

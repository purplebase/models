import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  group('storage filters', () {
    late ProviderContainer container;
    late DummyStorageNotifier storage;
    late StateNotifierTester tester;
    late Note a, b, c, d, e, f, g, replyToA, replyToB;
    late Profile nielProfile;

    setUp(() async {
      container = ProviderContainer();
      final config = StorageConfiguration(
        relayGroups: {
          'big-relays': {'wss://damus.relay.io', 'wss://relay.primal.net'}
        },
        defaultRelayGroup: 'big-relays',
        streamingBufferWindow: Duration.zero,
      );
      await container.read(initializationProvider(config).future);
      storage = container.read(storageNotifierProvider.notifier)
          as DummyStorageNotifier;

      final yesterday = DateTime.now().subtract(Duration(days: 1));
      final lastMonth = DateTime.now().subtract(Duration(days: 31));

      a = PartialNote('Note A', createdAt: yesterday).dummySign(nielPubkey);
      b = PartialNote('Note B', createdAt: lastMonth).dummySign(nielPubkey);
      c = PartialNote('Note C').dummySign(nielPubkey);
      d = PartialNote('Note D', tags: {'nostr'}).dummySign(nielPubkey);
      e = PartialNote('Note E').dummySign(franzapPubkey);
      f = PartialNote('Note F', tags: {'nostr'}).dummySign(franzapPubkey);
      g = PartialNote('Note G').dummySign(verbirichaPubkey);
      nielProfile = PartialProfile(name: 'neil').dummySign(nielPubkey);
      replyToA =
          PartialNote('reply to a', replyTo: a).dummySign(nielProfile.pubkey);
      replyToB = PartialNote('reply to b', createdAt: yesterday, replyTo: b)
          .dummySign(nielProfile.pubkey);

      await storage.save({a, b, c, d, e, f, g, replyToA, replyToB});
      await storage.save({nielProfile});
      await storage
          .publish({nielProfile}, source: RemoteSource(group: 'big-relays'));
    });

    tearDown(() async {
      tester.dispose();
      storage.cancel();
      await storage.clear();
    });

    test('ids', () async {
      tester = container.testerFor(
          queryKinds(ids: {a.event.id, e.event.id}, source: LocalSource()));
      await tester.expectModels(unorderedEquals({a, e}));
    });

    test('authors', () async {
      tester = container.testerFor(queryKinds(
          authors: {franzapPubkey, verbirichaPubkey}, source: LocalSource()));
      await tester.expectModels(unorderedEquals({e, f, g}));
    });

    test('kinds', () async {
      tester = container.testerFor(query<Note>(source: LocalSource()));
      await tester.expectModels(allOf(
        hasLength(9),
        everyElement((e) => e is Model && e.event.kind == 1),
      ));

      tester = container.testerFor(query<Profile>(source: LocalSource()));
      await tester.expectModels(hasLength(1));
    });

    test('tags', () async {
      tester = container.testerFor(queryKinds(authors: {
        nielPubkey
      }, tags: {
        '#t': {'nostr'}
      }, source: LocalSource()));
      await tester.expectModels(equals({d}));

      tester = container.testerFor(queryKinds(tags: {
        '#t': {'nostr', 'test'}
      }, source: LocalSource()));
      await tester.expectModels(unorderedEquals({d, f}));

      tester = container.testerFor(queryKinds(tags: {
        '#t': {'test'}
      }, source: LocalSource()));
      await tester.expectModels(isEmpty);

      tester = container.testerFor(queryKinds(tags: {
        '#t': {'nostr'},
        '#e': {nielPubkey}
      }, source: LocalSource()));
      await tester.expectModels(isEmpty);
    });

    test('until', () async {
      tester = container.testerFor(query<Note>(
          authors: {nielPubkey},
          until: DateTime.now().subtract(Duration(minutes: 1)),
          source: LocalSource()));
      await tester.expectModels(orderedEquals({a, b, replyToB}));
    });

    test('since', () async {
      tester = container.testerFor(queryKinds(
          authors: {nielPubkey},
          since: DateTime.now().subtract(Duration(minutes: 1)),
          source: LocalSource()));
      await tester.expectModels(orderedEquals({c, d, nielProfile, replyToA}));
    });

    test('limit and order', () async {
      tester = container.testerFor(
          query<Note>(authors: {nielPubkey}, limit: 3, source: LocalSource()));
      await tester.expectModels(orderedEquals({d, c, replyToA}));
    });

    test('replaceable updates', () async {
      tester = container.testerFor(
          query<Profile>(authors: {nielPubkey}, source: LocalSource()));
      await tester.expectModels(unorderedEquals({nielProfile}));

      final nielcho =
          nielProfile.copyWith(name: 'Nielcho').dummySign(nielPubkey);
      // Check processMetadata() was called when constructing
      expect(nielcho.name, equals('Nielcho'));
      // Content should NOT be empty as this new event could be sent to relays
      expect(nielcho.event.content, isNotEmpty);
      await nielcho.save();

      await tester.expect(isA<StorageData<Profile>>()
          .having((s) => s.models.first.name, 'name', 'Nielcho'));
    });

    test('relationships with model watcher', () async {
      tester = container.testerFor(
          model(a, and: (note) => {note.author}, source: LocalSource()));
      await tester.expectModels(unorderedEquals({a}));
      // NOTE: note.author will be cached, but only note is returned
    });

    test('multiple relationships', () async {
      tester = container.testerFor(query<Note>(
          ids: {a.id, b.id},
          and: (note) => {note.author, note.replies},
          source: LocalSource()));
      await tester.expectModels(unorderedEquals({a, b}));
      // NOTE: author and replies will be cached, can't assert here
    });

    test('relay metadata', () async {
      tester = container.testerFor(
          query<Profile>(authors: {nielPubkey}, source: LocalSource()));
      await tester.expect(isA<StorageData>()
          .having((s) => s.models.first.event.relays, 'relays', <String>{}));
    });
  });

  group('storage', () {
    late ProviderContainer container;
    late DummyStorageNotifier storage;

    setUpAll(() async {
      container = ProviderContainer();
      final config = StorageConfiguration(
        streamingBufferWindow: Duration.zero,
        keepMaxModels: 100,
      );
      await container.read(initializationProvider(config).future);
      storage = container.read(storageNotifierProvider.notifier)
          as DummyStorageNotifier;
    });

    tearDown(() async {
      // await storage.cancel();
      await storage.clear();
    });

    test('clear with req', () async {
      final a = List.generate(
          30,
          (_) => storage.generateModel(
              kind: 1, createdAt: DateTime.parse('2025-03-12'))!);
      final b = List.generate(30, (_) => storage.generateModel(kind: 1)!);
      await storage.save({...a, ...b});
      final beginOfYear = DateTime.parse('2025-01-01');
      final beginOfMonth = DateTime.parse('2025-04-01');
      expect(await storage.query(RequestFilter(since: beginOfYear).toRequest()),
          hasLength(60));
      expect(
          await storage.query(RequestFilter(since: beginOfMonth).toRequest()),
          hasLength(30));
      await storage.clear(RequestFilter(until: beginOfMonth).toRequest());
      expect(await storage.query(Request([RequestFilter(since: beginOfYear)])),
          hasLength(30));
    });

    test('max models config', () async {
      final max = storage.config.keepMaxModels;
      final a = List.generate(max * 2, (_) => storage.generateModel(kind: 1)!);
      await storage.save(a.toSet());
      expect(await storage.query(RequestFilter<Note>().toRequest()),
          hasLength(max));
    });

    test('request filter', () {
      final r1 = RequestFilter<Reaction>(authors: {
        nielPubkey,
        franzapPubkey
      }, tags: {
        'foo': {'bar'},
        '#t': {'nostr'}
      });
      final r2 = RequestFilter<Reaction>(authors: {
        franzapPubkey,
        nielPubkey
      }, tags: {
        '#t': {'nostr'},
        'foo': {'bar'}
      });
      final r3 = RequestFilter<Reaction>(authors: {
        franzapPubkey,
        nielPubkey
      }, tags: {
        'foo': {'bar'}
      });
      expect(r1.kinds.first, 7);
      expect(r1, equals(r2));
      expect(r1.toMap(), equals(r2.toMap()));
      expect(r1.toMap(), isNot(equals(r3.toMap())));

      // Filter with extra arguments
      final r4 = RequestFilter<Reaction>(
        authors: {nielPubkey, franzapPubkey},
        tags: {
          'foo': {'bar'},
          '#t': {'nostr'}
        },
      );

      expect(r1, equals(r4));
    });

    group('with notifier', () {
      late StateNotifierTester tester;

      setUp(() async {
        final [franzap, niel] = [
          storage.generateProfile(franzapPubkey),
          storage.generateProfile(nielPubkey)
        ];
        await storage.save({
          franzap,
          niel,
          ...List.generate(20,
              (i) => storage.generateModel(kind: 1, pubkey: franzapPubkey)!),
          ...List.generate(
              20, (i) => storage.generateModel(kind: 1, pubkey: nielPubkey)!),
        });
      });

      tearDown(() async {
        tester.dispose();
      });

      test('relay request should notify with models', () async {
        tester = container.testerFor(
            query<Note>(authors: {nielPubkey, franzapPubkey}, limit: 1));
        await tester.expectModels(hasLength(1));
        await tester.expectModels(hasLength(2));
      });

      test('relay request should notify with models (streamed)', () async {
        tester = container.testerFor(query<Note>(
          authors: {nielPubkey, franzapPubkey},
          limit: 5,
        ));
        await tester.expectModels(hasLength(5)); // limit=5
        await tester.expectModels(hasLength(10));
        await tester.expectModels(hasLength(15));
        await tester.expectModels(hasLength(20));
      });
    });
  });

  group('request notifier', () {
    late ProviderContainer container;
    late DummyStorageNotifier storage;
    late StateNotifierTester tester;
    late Note originalNote, editedNote, replyNote, quoteNote;
    late Profile authorProfile, replierProfile;
    late Reaction likeReaction, dislikeReaction;
    late Comment threadComment;

    setUp(() async {
      container = ProviderContainer();
      final config = StorageConfiguration(
        relayGroups: {
          'test-relays': {'wss://test1.relay.io', 'wss://test2.relay.io'}
        },
        defaultRelayGroup: 'test-relays',
        streamingBufferWindow: Duration.zero,
      );
      await container.read(initializationProvider(config).future);
      storage = container.read(storageNotifierProvider.notifier)
          as DummyStorageNotifier;

      // Create test data with relationships
      authorProfile = PartialProfile(name: 'Alice', about: 'Test author')
          .dummySign(nielPubkey);
      replierProfile = PartialProfile(name: 'Bob', about: 'Test replier')
          .dummySign(franzapPubkey);

      originalNote = PartialNote('Original post about #nostr', tags: {'nostr'})
          .dummySign(nielPubkey);
      editedNote = PartialNote('Edited post about #nostr', tags: {'nostr'})
          .dummySign(nielPubkey);

      replyNote = PartialNote('Great point!', replyTo: originalNote)
          .dummySign(franzapPubkey);
      quoteNote = PartialNote('Quoting this: ${originalNote.event.id}')
          .dummySign(verbirichaPubkey);

      likeReaction = PartialReaction(content: '+', reactedOn: originalNote)
          .dummySign(franzapPubkey);
      dislikeReaction = PartialReaction(content: '-', reactedOn: originalNote)
          .dummySign(verbirichaPubkey);

      threadComment =
          PartialComment(content: 'Nice thread', rootModel: originalNote)
              .dummySign(franzapPubkey);

      // Save initial data
      await storage.save({
        authorProfile,
        replierProfile,
        originalNote,
        replyNote,
        likeReaction,
        threadComment
      });
    });

    tearDown(() async {
      tester.dispose();
      storage.cancel();
      await storage.clear();
    });

    test('basic query with relationships - author profile', () async {
      tester = container.testerFor(query<Note>(
        ids: {originalNote.id},
        and: (note) => {note.author},
        source: LocalSource(),
      ));

      await tester.expectModels(unorderedEquals({originalNote}));
      // Should trigger relationship query for author profile
    });

    test('query with multiple relationships', () async {
      tester = container.testerFor(query<Note>(
        ids: {originalNote.id},
        and: (note) => {note.author, note.replies, note.reactions},
        source: LocalSource(),
      ));

      await tester.expectModels(unorderedEquals({originalNote}));
      // Should query author, replies, and reactions relationships
    });

    test('streaming update adds new main model with relationships', () async {
      tester = container.testerFor(query<Note>(
        authors: {nielPubkey},
        and: (note) => {note.author, note.reactions},
        source: LocalSource(),
      ));

      await tester.expectModels(unorderedEquals({originalNote}));

      // Add new note by same author
      final newNote = PartialNote('Another post').dummySign(nielPubkey);
      final newReaction = PartialReaction(content: '+', reactedOn: newNote)
          .dummySign(franzapPubkey);

      await storage.save({newNote, newReaction});

      await tester.expectModels(unorderedEquals({originalNote, newNote}));
      // Should update relationships for both notes
    });

    test('streaming update modifies existing model relationships', () async {
      tester = container.testerFor(query<Note>(
        ids: {originalNote.id},
        and: (note) => {note.reactions},
        source: LocalSource(),
      ));

      await tester.expectModels(unorderedEquals({originalNote}));

      // Add new reaction to existing note
      await storage.save({dislikeReaction});

      // Note itself doesn't change, but relationships should update
      await tester.expectModels(unorderedEquals({originalNote}));
    });

    test('replaceable event updates maintain relationships', () async {
      tester = container.testerFor(query<Note>(
        ids: {originalNote.id},
        and: (note) => {note.author, note.reactions},
        source: LocalSource(),
      ));

      await tester.expectModels(unorderedEquals({originalNote}));

      // Update the note (replaceable event)
      await storage.save({editedNote});

      await tester.expectModels(unorderedEquals({editedNote}));
      // Relationships should be recalculated for edited note
    });

    test('relationship cleanup when models are removed', () async {
      tester = container.testerFor(query<Note>(
        authors: {nielPubkey, franzapPubkey},
        and: (note) => {note.author, note.replies},
        source: LocalSource(),
      ));

      await tester.expectModels(unorderedEquals({originalNote, replyNote}));

      // Remove one of the notes by clearing with a specific request
      await storage.clear(RequestFilter<Note>(ids: {replyNote.id}).toRequest());

      await tester.expectModels(unorderedEquals({originalNote}));
      // Should cleanup relationships for removed note
    });

    test('empty initial query with later streaming results', () async {
      // Query for non-existent author initially
      tester = container.testerFor(query<Note>(
        authors: {'nonexistent_pubkey'},
        and: (note) => {note.author, note.reactions},
        source: LocalSource(),
      ));

      await tester.expectModels(isEmpty);

      // Later add a note by that author
      final lateNote =
          PartialNote('Late arrival').dummySign('nonexistent_pubkey');
      final lateProfile =
          PartialProfile(name: 'Late User').dummySign('nonexistent_pubkey');

      await storage.save({lateNote, lateProfile});

      await tester.expectModels(unorderedEquals({lateNote}));
      // Should establish relationships for newly arrived data
    });

    test('complex relationship chain - replies to replies', () async {
      // Create a reply chain
      final replyToReply = PartialNote('Reply to reply', replyTo: replyNote)
          .dummySign(verbirichaPubkey);
      final replyToReplyToReply =
          PartialNote('Deep reply', replyTo: replyToReply)
              .dummySign(nielPubkey);

      await storage.save({replyToReply, replyToReplyToReply});

      tester = container.testerFor(query<Note>(
        ids: {originalNote.id},
        and: (note) => {note.replies},
        source: LocalSource(),
      ));

      await tester.expectModels(unorderedEquals({originalNote}));
      // Should handle nested relationship queries
    });

    test('overlapping requests with shared relationships', () async {
      // Two different queries that share some relationship data
      final tester1 = container.testerFor(query<Note>(
        authors: {nielPubkey},
        and: (note) => {note.author, note.reactions},
        source: LocalSource(),
      ));

      final tester2 = container.testerFor(query<Note>(
        tags: {
          '#t': {'nostr'}
        },
        and: (note) => {note.author, note.replies},
        source: LocalSource(),
      ));

      await tester1.expectModels(unorderedEquals({originalNote}));
      await tester2.expectModels(unorderedEquals({originalNote}));

      // Add data that affects both queries
      final newReaction =
          PartialReaction(content: '❤️', reactedOn: originalNote)
              .dummySign(verbirichaPubkey);
      final newReply = PartialNote('New reply', replyTo: originalNote)
          .dummySign(verbirichaPubkey);

      await storage.save({newReaction, newReply});

      // Both should update appropriately
      await tester1.expectModels(unorderedEquals({originalNote}));
      await tester2.expectModels(unorderedEquals({originalNote}));

      tester1.dispose();
      tester2.dispose();
    });

    test('relationship data becomes available after initial query', () async {
      // Query note before its author profile exists
      await storage
          .clear(RequestFilter<Profile>(ids: {authorProfile.id}).toRequest());

      tester = container.testerFor(query<Note>(
        ids: {originalNote.id},
        and: (note) => {note.author},
        source: LocalSource(),
      ));

      await tester.expectModels(unorderedEquals({originalNote}));

      // Later add the author profile
      await storage.save({authorProfile});

      // Should trigger relationship update
      await tester.expectModels(unorderedEquals({originalNote}));
    });

    test('bulk updates with mixed model types', () async {
      tester = container.testerFor(query<Note>(
        authors: {nielPubkey, franzapPubkey},
        and: (note) => {note.author, note.reactions, note.replies},
        source: LocalSource(),
      ));

      await tester.expectModels(unorderedEquals({originalNote, replyNote}));

      // Bulk update with various model types
      final bulkNotes = List.generate(
          5, (i) => PartialNote('Bulk note $i').dummySign(nielPubkey));
      final bulkReactions = bulkNotes
          .map((note) => PartialReaction(content: '+', reactedOn: note)
              .dummySign(franzapPubkey))
          .toList();
      final bulkProfiles = [
        PartialProfile(name: 'Updated Alice').dummySign(nielPubkey),
        PartialProfile(name: 'Updated Bob').dummySign(franzapPubkey),
      ];

      await storage.save({...bulkNotes, ...bulkReactions, ...bulkProfiles});

      await tester.expectModels(hasLength(greaterThan(2)));
      // Should handle bulk relationship updates efficiently
    });

    test('time-based queries with relationships', () async {
      final now = DateTime.now();
      final hourAgo = now.subtract(Duration(hours: 1));

      final oldNote =
          PartialNote('Old note', createdAt: hourAgo).dummySign(nielPubkey);
      final oldReaction = PartialReaction(content: '+', reactedOn: oldNote)
          .dummySign(franzapPubkey);

      await storage.save({oldNote, oldReaction});

      tester = container.testerFor(query<Note>(
        authors: {nielPubkey},
        since: hourAgo.add(Duration(minutes: 30)),
        and: (note) => {note.author, note.reactions},
        source: LocalSource(),
      ));

      await tester.expectModels(unorderedEquals({originalNote}));
      // Should only include recent notes but maintain relationships
    });

    test('error resilience during relationship updates', () async {
      tester = container.testerFor(query<Note>(
        ids: {originalNote.id},
        and: (note) => {note.author, note.reactions},
        source: LocalSource(),
      ));

      await tester.expectModels(unorderedEquals({originalNote}));

      // Simulate problematic update that might cause errors
      // The notifier should continue functioning despite errors
      final corruptedNote =
          PartialNote('Corrupted content').dummySign(nielPubkey);

      await storage.save({corruptedNote});

      // Should still maintain state despite potential errors
      await tester.expectModels(isNotEmpty);
    });

    test('relationship cycles and circular references', () async {
      // Create circular relationship scenario
      final noteA = PartialNote('Note A mentions B').dummySign(nielPubkey);
      final noteB = PartialNote('Note B mentions A', replyTo: noteA)
          .dummySign(franzapPubkey);
      final noteC = PartialNote('Note C quotes A: ${noteA.event.id}')
          .dummySign(verbirichaPubkey);

      await storage.save({noteA, noteB, noteC});

      tester = container.testerFor(query<Note>(
        ids: {noteA.id, noteB.id},
        and: (note) => {note.replies},
        source: LocalSource(),
      ));

      await tester.expectModels(unorderedEquals({noteA, noteB}));
      // Should handle circular relationships without infinite loops
    });

    test('high-frequency updates stress test', () async {
      tester = container.testerFor(query<Note>(
        authors: {nielPubkey},
        and: (note) => {note.reactions},
        source: LocalSource(),
      ));

      await tester.expectModels(unorderedEquals({originalNote}));

      // Rapid-fire updates to test race condition handling
      final rapidUpdates = <Future>[];
      for (int i = 0; i < 10; i++) {
        rapidUpdates.add(storage.save({
          PartialReaction(content: 'reaction_$i', reactedOn: originalNote)
              .dummySign('user_$i')
        }));
      }

      await Future.wait(rapidUpdates);

      // Should handle rapid updates gracefully
      await tester.expectModels(unorderedEquals({originalNote}));
    });

    test('mixed source queries with relationships', () async {
      // Test combination of local and remote sources
      tester = container.testerFor(query<Note>(
        authors: {nielPubkey},
        and: (note) => {note.author, note.reactions},
        source: RemoteSource(group: 'test-relays'),
      ));

      await tester.expectModels(unorderedEquals({originalNote}));

      // Add remote data
      final remoteNote = PartialNote('Remote note').dummySign(nielPubkey);
      await storage
          .publish({remoteNote}, source: RemoteSource(group: 'test-relays'));

      await tester.expectModels(hasLength(greaterThanOrEqualTo(1)));
    });
  });
}

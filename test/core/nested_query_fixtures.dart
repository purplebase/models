import 'package:models/models.dart';

import '../helpers.dart';

/// Test fixtures for nested query tests.
///
/// Creates a realistic data structure:
/// - Multiple authors (profiles)
/// - Apps owned by different authors
/// - Releases for each app (multiple versions)
/// - FileMetadata for each release
/// - Notes by authors with reactions and replies
class NestedQueryFixtures {
  final String author1 = franzapPubkey;
  final String author2 = nielPubkey;
  final String author3 = Utils.generateRandomHex64();

  late final Profile profile1;
  late final Profile profile2;
  late final Profile profile3;

  late final App app1;
  late final App app2;
  late final App app3;

  late final Release release1v1;
  late final Release release1v2;
  late final Release release2v1;

  late final FileMetadata metadata1v1;
  late final FileMetadata metadata1v2;
  late final FileMetadata metadata2v1;

  late final Note note1;
  late final Note note2;
  late final Note note3;

  late final Reaction reaction1;
  late final Reaction reaction2;

  late final Note reply1;

  NestedQueryFixtures() {
    _createProfiles();
    _createApps();
    _createReleases();
    _createFileMetadata();
    _createNotes();
    _createReactions();
    _createReplies();
  }

  void _createProfiles() {
    profile1 = (PartialProfile()
          ..name = 'Alice Developer'
          ..about = 'App developer')
        .dummySign(author1);

    profile2 = (PartialProfile()
          ..name = 'Bob Builder'
          ..about = 'Another developer')
        .dummySign(author2);

    profile3 = (PartialProfile()
          ..name = 'Charlie Coder'
          ..about = 'Third developer')
        .dummySign(author3);
  }

  void _createApps() {
    app1 = (PartialApp()
          ..identifier = 'com.alice.app1'
          ..name = 'Alice App One'
          ..description = 'First app by Alice')
        .dummySign(author1);

    app2 = (PartialApp()
          ..identifier = 'com.alice.app2'
          ..name = 'Alice App Two'
          ..description = 'Second app by Alice')
        .dummySign(author1);

    app3 = (PartialApp()
          ..identifier = 'com.bob.app1'
          ..name = 'Bob App'
          ..description = 'App by Bob')
        .dummySign(author2);
  }

  void _createReleases() {
    final partial1v1 = PartialRelease()..identifier = 'com.alice.app1@1.0.0';
    partial1v1.event.addTag('i', ['com.alice.app1']);
    partial1v1.event.addTag('version', ['1.0.0']);
    release1v1 = partial1v1.dummySign(author1);

    final partial1v2 = PartialRelease()..identifier = 'com.alice.app1@2.0.0';
    partial1v2.event.addTag('i', ['com.alice.app1']);
    partial1v2.event.addTag('version', ['2.0.0']);
    release1v2 = partial1v2.dummySign(author1);

    final partial2v1 = PartialRelease()..identifier = 'com.bob.app1@1.0.0';
    partial2v1.event.addTag('i', ['com.bob.app1']);
    partial2v1.event.addTag('version', ['1.0.0']);
    release2v1 = partial2v1.dummySign(author2);
  }

  void _createFileMetadata() {
    metadata1v1 = (PartialFileMetadata()
          ..version = '1.0.0'
          ..appIdentifier = 'com.alice.app1')
        .dummySign(author1);

    metadata1v2 = (PartialFileMetadata()
          ..version = '2.0.0'
          ..appIdentifier = 'com.alice.app1')
        .dummySign(author1);

    metadata2v1 = (PartialFileMetadata()
          ..version = '1.0.0'
          ..appIdentifier = 'com.bob.app1')
        .dummySign(author2);
  }

  void _createNotes() {
    note1 = PartialNote('Hello from Alice!').dummySign(author1);
    note2 = PartialNote('Hello from Bob!').dummySign(author2);
    note3 = PartialNote('Hello from Charlie!').dummySign(author3);
  }

  void _createReactions() {
    final partial1 = PartialReaction();
    partial1.event.addTag('e', [note1.event.id]);
    partial1.event.addTag('p', [author1]);
    reaction1 = partial1.dummySign(author2);

    final partial2 = PartialReaction();
    partial2.event.addTag('e', [note1.event.id]);
    partial2.event.addTag('p', [author1]);
    reaction2 = partial2.dummySign(author3);
  }

  void _createReplies() {
    // NIP-10: reply with proper markers
    // Format: ['e', <event-id>, <relay-url>, <marker>]
    // marker 'root' indicates this is a direct reply to a root note
    final partial = PartialNote('Reply to Alice!');
    partial.event.addTag('e', [note1.event.id, '', 'root']);
    partial.event.addTag('p', [author1]);
    reply1 = partial.dummySign(author2);
  }

  /// All models for initial save
  Set<Model> get allModels => {
        profile1,
        profile2,
        profile3,
        app1,
        app2,
        app3,
        release1v1,
        release1v2,
        release2v1,
        metadata1v1,
        metadata1v2,
        metadata2v1,
        note1,
        note2,
        note3,
        reaction1,
        reaction2,
        reply1,
      };

  /// Profiles only
  Set<Profile> get profiles => {profile1, profile2, profile3};

  /// Apps only
  Set<App> get apps => {app1, app2, app3};

  /// Releases only
  Set<Release> get releases => {release1v1, release1v2, release2v1};

  /// Notes only
  Set<Note> get notes => {note1, note2, note3};

  /// All authors
  Set<String> get authors => {author1, author2, author3};
}


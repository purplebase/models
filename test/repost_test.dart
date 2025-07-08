import 'dart:convert';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;

  setUpAll(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    ref = container.read(refProvider);
  });

  group('Repost Tests', () {
    test('can create and parse a Repost (kind 6)', () async {
      // Create a note to repost
      final originalNote = PartialNote('This is the original note content');
      final signedNote = originalNote.dummySign(nielPubkey);

      // Create a repost of the note
      final repost = PartialRepost(
        content: jsonEncode(
            signedNote.toMap()), // NIP-18: content should be stringified JSON
        repostedNote: signedNote,
        relayUrl: 'wss://relay.example.com',
      );
      final signedRepost = repost.dummySign(verbirichaPubkey);

      // Verify the repost has correct properties
      expect(signedRepost.event.kind, equals(6));
      expect(signedRepost.content, isNotEmpty);
      expect(signedRepost.repostedNoteId, equals(signedNote.id));
      expect(signedRepost.repostedNotePubkey, equals(signedNote.event.pubkey));
      expect(signedRepost.relayUrl, equals('wss://relay.example.com'));

      // Verify the e tag is properly set
      final eTags = signedRepost.event.getTagSet('e');
      expect(eTags, hasLength(1));
      expect(eTags.first[1], equals(signedNote.id));
      expect(eTags.first[2], equals('wss://relay.example.com'));

      // Verify the p tag is properly set
      final pTags = signedRepost.event.getTagSet('p');
      expect(pTags, hasLength(1));
      expect(pTags.first[1], equals(signedNote.event.pubkey));
    });

    test('can create and parse a GenericRepost (kind 16)', () async {
      // Create a note first (needed for reaction)
      final noteToReactTo = PartialNote('Note to react to');
      final signedNoteToReactTo = noteToReactTo.dummySign(franzapPubkey);

      // Create a reaction to repost (any non-kind-1 event)
      final originalReaction =
          PartialReaction(content: '+', reactedOn: signedNoteToReactTo);
      final signedReaction = originalReaction.dummySign(nielPubkey);

      // Create a generic repost of the reaction
      final genericRepost = PartialGenericRepost(
        content: jsonEncode(signedReaction.toMap()),
        repostedEvent: signedReaction,
        relayUrl: 'wss://relay.example.com',
        repostedEventKind: 7, // reaction kind
      );
      final signedGenericRepost = genericRepost.dummySign(verbirichaPubkey);

      // Verify the generic repost has correct properties
      expect(signedGenericRepost.event.kind, equals(16));
      expect(signedGenericRepost.content, isNotEmpty);
      expect(signedGenericRepost.repostedEventId, equals(signedReaction.id));
      expect(signedGenericRepost.repostedEventPubkey,
          equals(signedReaction.event.pubkey));
      expect(signedGenericRepost.repostedEventKind, equals(7));
      expect(signedGenericRepost.relayUrl, equals('wss://relay.example.com'));

      // Verify the e tag is properly set
      final eTags = signedGenericRepost.event.getTagSet('e');
      expect(eTags, hasLength(1));
      expect(eTags.first[1], equals(signedReaction.id));
      expect(eTags.first[2], equals('wss://relay.example.com'));

      // Verify the p tag is properly set
      final pTags = signedGenericRepost.event.getTagSet('p');
      expect(pTags, hasLength(1));
      expect(pTags.first[1], equals(signedReaction.event.pubkey));

      // Verify the k tag is properly set
      final kTags = signedGenericRepost.event.getTagSet('k');
      expect(kTags, hasLength(1));
      expect(kTags.first[1], equals('7'));
    });

    test('Repost relationships work correctly', () async {
      // Create a note
      final originalNote = PartialNote('Test note for repost relationships');
      final signedNote = originalNote.dummySign(nielPubkey);

      // Create a repost
      final repost = PartialRepost(repostedNote: signedNote);
      final signedRepost = repost.dummySign(verbirichaPubkey);

      // Save both to storage
      await container
          .read(storageNotifierProvider.notifier)
          .save({signedNote, signedRepost});

      // Verify the repost can find the original note
      expect(signedRepost.repostedNote.value, equals(signedNote));

      // Verify the note can find its reposts
      expect(signedNote.reposts.toList(), contains(signedRepost));
    });

    test('GenericRepost relationships work correctly', () async {
      // Create a note first (needed for reaction)
      final noteToReactTo = PartialNote('Note to react to');
      final signedNoteToReactTo = noteToReactTo.dummySign(franzapPubkey);

      // Create a reaction
      final originalReaction =
          PartialReaction(content: '❤️', reactedOn: signedNoteToReactTo);
      final signedReaction = originalReaction.dummySign(nielPubkey);

      // Create a generic repost
      final genericRepost = PartialGenericRepost(repostedEvent: signedReaction);
      final signedGenericRepost = genericRepost.dummySign(verbirichaPubkey);

      // Save both to storage
      await container
          .read(storageNotifierProvider.notifier)
          .save({signedReaction, signedGenericRepost});

      // Verify the generic repost can find the original event
      expect(signedGenericRepost.repostedEvent.value, equals(signedReaction));

      // Verify the reaction can find its generic reposts
      expect(signedReaction.genericReposts.toList(),
          contains(signedGenericRepost));
    });
  });
}

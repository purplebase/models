/// Tests for core functionality: events, relationships, utilities.
library;

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers/helpers.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    container = await createTestContainer();
  });

  tearDown(() => container.tearDown());

  group('MutableEvent', () {
    test('initializes with defaults', () {
      final partial = PartialNote('test');
      expect(partial.event.kind, 1);
      expect(partial.event.tags, isEmpty);
      expect(partial.event.createdAt, isA<DateTime>());
    });

    group('tag manipulation', () {
      late PartialNote partial;

      setUp(() {
        partial = PartialNote('test');
      });

      test('addTag appends to tags', () {
        partial.event.addTag('p', ['pubkey123']);
        expect(partial.event.tags.length, 1);
        expect(partial.event.tags.first, ['p', 'pubkey123']);
      });

      test('addTagValue adds single value', () {
        partial.event.addTagValue('t', 'nostr');
        expect(partial.event.getFirstTagValue('t'), 'nostr');
      });

      test('setTagValue replaces existing', () {
        partial.event.addTagValue('d', 'original');
        partial.event.setTagValue('d', 'updated');
        expect(partial.event.getTagSetValues('d').length, 1);
        expect(partial.event.getFirstTagValue('d'), 'updated');
      });

      test('removeTag removes by name', () {
        partial.event.addTagValue('t', 'nostr');
        partial.event.addTagValue('t', 'bitcoin');
        partial.event.removeTag('t');
        expect(partial.event.containsTag('t'), isFalse);
      });

      test('removeTagWithValue removes matching tags', () {
        partial.event.addTag('e', ['id1', 'relay1']);
        partial.event.addTag('e', ['id2', 'relay2']);
        partial.event.removeTagWithValue('e', 'id1');
        expect(partial.event.getTagSetValues('e'), {'id2'});
      });

      test('getTagSet returns all matching tags', () {
        partial.event.addTag('p', ['pub1']);
        partial.event.addTag('p', ['pub2']);
        partial.event.addTag('e', ['event1']);
        expect(partial.event.getTagSet('p').length, 2);
      });

      test('getFirstTag returns first or null', () {
        expect(partial.event.getFirstTag('p'), isNull);
        partial.event.addTag('p', ['pub1']);
        partial.event.addTag('p', ['pub2']);
        expect(partial.event.getFirstTag('p'), ['p', 'pub1']);
      });

      test('containsTag checks existence', () {
        expect(partial.event.containsTag('p'), isFalse);
        partial.event.addTagValue('p', 'test');
        expect(partial.event.containsTag('p'), isTrue);
      });
    });
  });

  group('ImmutableEvent', () {
    test('generates addressableId correctly', () {
      // Regular event: uses event id
      final note = PartialNote('test').dummySign(Pubkeys.niel);
      expect(note.event.addressableId, note.id);

      // Replaceable event: uses kind:pubkey:
      final profile = PartialProfile(name: 'test').dummySign(Pubkeys.niel);
      expect(profile.event.addressableId, '0:${Pubkeys.niel}:');

      // Parameterized replaceable: uses kind:pubkey:identifier
      final article =
          (PartialArticle('Test', 'Body')..identifier = 'my-id')
              .dummySign(Pubkeys.niel);
      expect(article.event.addressableId, '30023:${Pubkeys.niel}:my-id');
    });

    test('generates shareableId (NIP-19)', () {
      // Profile -> nprofile
      final profile = PartialProfile(name: 'test').dummySign(Pubkeys.niel);
      expect(profile.event.shareableId, startsWith('nprofile1'));

      // Note -> nevent
      final note = PartialNote('test').dummySign(Pubkeys.niel);
      expect(note.event.shareableId, startsWith('nevent1'));

      // Article -> naddr
      final article =
          (PartialArticle('Test', 'Body')..identifier = 'my-id')
              .dummySign(Pubkeys.niel);
      expect(article.event.shareableId, startsWith('naddr1'));
    });

    test('toMap includes all fields', () {
      final note = PartialNote('hello').dummySign(Pubkeys.niel);
      final map = note.toMap();

      expect(map['id'], isNotNull);
      expect(map['content'], 'hello');
      expect(map['pubkey'], Pubkeys.niel);
      expect(map['kind'], 1);
      expect(map['created_at'], isA<int>());
      expect(map['tags'], isA<List>());
      // Note: sig may be null when keepSignatures is false in config
    });
  });

  group('Relationship', () {
    test('BelongsTo resolves related model', () async {
      final profile = PartialProfile(name: 'Author').dummySign(Pubkeys.niel);
      final note = PartialNote('hello').dummySign(Pubkeys.niel);
      await container.storage.save({profile, note});

      expect(note.author.value, profile);
      expect(note.author.isPresent, isTrue);
    });

    test('BelongsTo returns null when not found', () async {
      final note = PartialNote('hello').dummySign(Pubkeys.niel);
      await container.storage.save({note});
      // No profile saved
      expect(note.author.value, isNull);
      expect(note.author.isPresent, isFalse);
    });

    test('HasMany resolves related models', () async {
      final note = PartialNote('hello').dummySign(Pubkeys.niel);
      final reply1 =
          PartialNote('reply 1', replyTo: note).dummySign(Pubkeys.franzap);
      final reply2 =
          PartialNote('reply 2', replyTo: note).dummySign(Pubkeys.verbiricha);
      await container.storage.save({note, reply1, reply2});

      expect(note.replies.length, 2);
      expect(note.replies.toSet(), {reply1, reply2});
      expect(note.replies.isEmpty, isFalse);
      expect(note.replies.isNotEmpty, isTrue);
    });

    test('HasMany returns empty when no matches', () async {
      final note = PartialNote('hello').dummySign(Pubkeys.niel);
      await container.storage.save({note});

      expect(note.replies.length, 0);
      expect(note.replies.isEmpty, isTrue);
      expect(note.replies.firstOrNull, isNull);
    });

    test('relationships cache and invalidate correctly', () async {
      final note = PartialNote('hello').dummySign(Pubkeys.niel);
      await container.storage.save({note});

      // First access, no replies
      expect(note.replies.length, 0);

      // Add a reply
      final reply =
          PartialNote('reply', replyTo: note).dummySign(Pubkeys.franzap);
      await container.storage.save({reply});

      // Cache should be invalidated, new reply visible
      expect(note.replies.length, 1);
    });
  });

  group('Utils', () {
    test('generateRandomHex64 produces 64 char hex', () {
      final hex = Utils.generateRandomHex64();
      expect(hex.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(hex), isTrue);
    });

    test('generateRandomHex64 produces unique values', () {
      final values = List.generate(100, (_) => Utils.generateRandomHex64());
      expect(values.toSet().length, 100);
    });

    test('derivePublicKey works correctly', () {
      const privateKey =
          'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8';
      final publicKey = Utils.derivePublicKey(privateKey);
      expect(publicKey.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(publicKey), isTrue);
    });

    group('NIP-19 encoding/decoding', () {
      test('encodes npub correctly', () {
        final encoded = Utils.encodeShareableIdentifier(
          NpubInput(value: Pubkeys.niel),
        );
        expect(encoded, startsWith('npub1'));
      });

      test('decodes npub correctly', () {
        final encoded = Utils.encodeShareableIdentifier(
          NpubInput(value: Pubkeys.niel),
        );
        final decoded = Utils.decodeShareableIdentifier(encoded);
        expect(decoded, isA<ProfileData>());
        expect((decoded as ProfileData).pubkey, Pubkeys.niel);
      });

      test('encodes/decodes nprofile with relays', () {
        final encoded = Utils.encodeShareableIdentifier(
          ProfileInput(
            pubkey: Pubkeys.niel,
            relays: ['wss://relay.example.com'],
          ),
        );
        expect(encoded, startsWith('nprofile1'));

        final decoded =
            Utils.decodeShareableIdentifier(encoded) as ProfileData;
        expect(decoded.pubkey, Pubkeys.niel);
        expect(decoded.relays, contains('wss://relay.example.com'));
      });

      test('encodes/decodes nevent', () {
        const eventId =
            'abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234';
        final encoded = Utils.encodeShareableIdentifier(
          EventInput(eventId: eventId),
        );
        expect(encoded, startsWith('nevent1'));

        final decoded = Utils.decodeShareableIdentifier(encoded) as EventData;
        expect(decoded.eventId, eventId);
      });

      test('encodes/decodes naddr', () {
        final encoded = Utils.encodeShareableIdentifier(
          AddressInput(
            identifier: 'my-article',
            author: Pubkeys.niel,
            kind: 30023,
          ),
        );
        expect(encoded, startsWith('naddr1'));

        final decoded =
            Utils.decodeShareableIdentifier(encoded) as AddressData;
        expect(decoded.identifier, 'my-article');
        expect(decoded.author, Pubkeys.niel);
        expect(decoded.kind, 30023);
      });

      test('handles nostr: URI prefix', () {
        final encoded = Utils.encodeShareableIdentifier(
          NpubInput(value: Pubkeys.niel),
        );
        final withPrefix = 'nostr:$encoded';
        final decoded = Utils.decodeShareableIdentifier(withPrefix);
        expect((decoded as ProfileData).pubkey, Pubkeys.niel);
      });

      test('decodeShareableToString convenience method', () {
        final npub = Utils.encodeShareableIdentifier(
          NpubInput(value: Pubkeys.niel),
        );
        expect(Utils.decodeShareableToString(npub), Pubkeys.niel);

        // Already decoded returns as-is
        expect(Utils.decodeShareableToString(Pubkeys.niel), Pubkeys.niel);
      });

      test('encodeShareableFromString handles already encoded', () {
        final npub = Utils.encodeShareableIdentifier(
          NpubInput(value: Pubkeys.niel),
        );
        // Should return as-is if already encoded
        expect(Utils.encodeShareableFromString(npub, type: 'npub'), npub);
      });
    });

    test('isEventReplaceable', () {
      expect(Utils.isEventReplaceable(0), isTrue); // Profile
      expect(Utils.isEventReplaceable(3), isTrue); // ContactList
      expect(Utils.isEventReplaceable(1), isFalse); // Note
      expect(Utils.isEventReplaceable(10002), isTrue); // RelayList (10000-19999)
      expect(Utils.isEventReplaceable(30023), isTrue); // Article (30000-39999)
    });

    test('extractImetaUrls parses imeta tags', () {
      final tags = {
        ['imeta', 'url https://example.com/video.mp4', 'm video/mp4'],
        ['imeta', 'url https://example.com/video2.mp4', 'm video/mp4'],
      };
      final urls = Utils.extractImetaUrls(tags);
      expect(
          urls,
          containsAll([
            'https://example.com/video.mp4',
            'https://example.com/video2.mp4',
          ]));
    });
  });

  group('Model identity', () {
    test('replaceable events use kind:pubkey for equality', () async {
      final profile1 = PartialProfile(name: 'First').dummySign(Pubkeys.niel);
      await container.storage.save({profile1});

      // Update same profile (same kind, same pubkey)
      final profile2 =
          profile1.copyWith(name: 'Second').dummySign(Pubkeys.niel);
      await container.storage.save({profile2});

      // Should only have one profile
      final profiles = await container.storage.query(
        RequestFilter<Profile>(authors: {Pubkeys.niel}).toRequest(),
      );
      expect(profiles.length, 1);
      expect(profiles.first.name, 'Second');
    });

    test('parameterized replaceable events use kind:pubkey:d for equality',
        () async {
      final article1 =
          (PartialArticle('V1', 'Body')..identifier = 'my-id')
              .dummySign(Pubkeys.niel);
      await container.storage.save({article1});

      // Update same article (same d-tag)
      final article2 =
          (PartialArticle('V2', 'Body')..identifier = 'my-id')
              .dummySign(Pubkeys.niel);
      await container.storage.save({article2});

      final articles = await container.storage.query(
        RequestFilter<Article>(authors: {Pubkeys.niel}).toRequest(),
      );
      expect(articles.length, 1);
      expect(articles.first.title, 'V2');
    });

    test('regular events use event id for equality', () async {
      final note1 = PartialNote('First').dummySign(Pubkeys.niel);
      final note2 = PartialNote('Second').dummySign(Pubkeys.niel);
      await container.storage.save({note1, note2});

      final notes = await container.storage.query(
        RequestFilter<Note>(authors: {Pubkeys.niel}).toRequest(),
      );
      expect(notes.length, 2);
    });
  });
}

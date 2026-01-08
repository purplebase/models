import 'package:test/test.dart';
import 'package:models/models.dart';
import '../helpers.dart';

void main() {
  group('Shareable Identifier Encoding/Decoding', () {
    test('should decode the specific nprofile and extract correct pubkey', () {
      const nprofile =
          'nprofile1qythwumn8ghj7un9d3shjtnswf5k6ctv9ehx2ap0qyvhwumn8ghj7urjv4kkjatd9ec8y6tdv9kzumn9wshsz8rhwden5te0wfjkccte9e3xjarrda5kuurpwf4jucm0d5hsqgrlzamsdttwpt48t20rx3welldwvankltljfxlx276evd67rnknjy2t5aec';
      const expectedPubkey =
          '7f177706ad6e0aea75a9e3345d9ffdae67676faff249be657b596375e1ced391';

      final pubkey = nprofile.decodeShareable();
      expect(pubkey, equals(expectedPubkey));
    });

    test('should decode nprofile using Utils.decodeShareable', () {
      const nprofile =
          'nprofile1qythwumn8ghj7un9d3shjtnswf5k6ctv9ehx2ap0qyvhwumn8ghj7urjv4kkjatd9ec8y6tdv9kzumn9wshsz8rhwden5te0wfjkccte9e3xjarrda5kuurpwf4jucm0d5hsqgrlzamsdttwpt48t20rx3welldwvankltljfxlx276evd67rnknjy2t5aec';
      const expectedPubkey =
          '7f177706ad6e0aea75a9e3345d9ffdae67676faff249be657b596375e1ced391';

      final pubkey = Utils.decodeShareableToString(nprofile);
      expect(pubkey, equals(expectedPubkey));
    });

    test('should decode nevent using Utils.decodeShareable', () {
      // Use a valid nevent string from the existing test data
      final eventId =
          'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1';
      final author = franzapPubkey;
      final relays = ['wss://relay.primal.net'];

      // Encode event to nevent first
      final nevent = Utils.encodeShareableIdentifier(
        EventInput(eventId: eventId, relays: relays, author: author),
      );

      // Now decode it using the simpler method
      final decodedEventId = Utils.decodeShareableToString(nevent);
      expect(decodedEventId, equals(eventId));
    });

    test('should return hex strings as-is when using Utils.decodeShareable',
        () {
      const hexString =
          '7f177706ad6e0aea75a9e3345d9ffdae67676faff249be657b596375e1ced391';

      final result = Utils.decodeShareableToString(hexString);
      expect(result, equals(hexString));
    });

    test('should roundtrip encode and decode nprofile with pubkey only', () {
      final pubkey = nielPubkey;

      // Encode pubkey to nprofile
      final nprofile = Utils.encodeShareableIdentifier(
        ProfileInput(pubkey: pubkey),
      );

      // Decode nprofile back to pubkey
      final decoded = Utils.decodeShareableIdentifier(nprofile);
      expect(decoded, isA<ProfileData>());
      final decodedPubkey = (decoded as ProfileData).pubkey;

      expect(decodedPubkey, equals(pubkey));
      expect(nprofile.startsWith('nprofile'), isTrue);
    });

    test('should roundtrip encode and decode nprofile with relays', () {
      final pubkey = verbirichaPubkey;
      final relays = ['wss://relay.damus.io', 'wss://relay.nostr.band'];

      // Encode pubkey with relays to nprofile
      final nprofile = Utils.encodeShareableIdentifier(
        ProfileInput(pubkey: pubkey, relays: relays),
      );

      // Decode nprofile back
      final decoded = Utils.decodeShareableIdentifier(nprofile);
      expect(decoded, isA<ProfileData>());
      final decodedPubkey = (decoded as ProfileData).pubkey;

      expect(decodedPubkey, equals(pubkey));
      expect(decoded.relays, equals(relays));
      expect(nprofile.startsWith('nprofile'), isTrue);
    });

    test('should roundtrip encode and decode naddr', () {
      final identifier =
          '30023:a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be:verbiricha';
      final author = nielPubkey;
      final kind = 30023;
      final relays = ['wss://relay.damus.io'];

      // Encode address to naddr
      final naddr = Utils.encodeShareableIdentifier(
        AddressInput(
            identifier: identifier, relays: relays, author: author, kind: kind),
      );

      // Decode naddr back
      final decoded = Utils.decodeShareableIdentifier(naddr);
      expect(decoded, isA<AddressData>());
      final decodedIdentifier = (decoded as AddressData).identifier;

      expect(decodedIdentifier, equals(identifier));
      expect(decoded.author, equals(author));
      expect(decoded.kind, equals(kind));
      expect(decoded.relays, equals(relays));
      expect(naddr.startsWith('naddr'), isTrue);
    });

    test('should handle multiple relays correctly', () {
      final pubkey =
          'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8';
      final relays = [
        'wss://relay.damus.io',
        'wss://relay.nostr.band',
        'wss://relay.primal.net',
        'wss://relay.current.fyi'
      ];

      // Encode with multiple relays
      final nprofile = Utils.encodeShareableIdentifier(
        ProfileInput(pubkey: pubkey, relays: relays),
      );

      // Decode and verify all relays
      final decoded = Utils.decodeShareableIdentifier(nprofile);
      expect(decoded, isA<ProfileData>());
      expect((decoded as ProfileData).pubkey, equals(pubkey));
      expect(decoded.relays, equals(relays));
      expect(decoded.relays!.length, equals(4));
    });

    test('should handle nprofile with all optional fields', () {
      final pubkey =
          '79f00d3f5a19ec806189fcab03c1be4ff81d18ee4f653c88fac41fe8f04a9f5f';
      final relays = ['wss://relay.damus.io'];
      final author =
          '83e818dfbeccea56b0f551576b3fd39a7a50e1d8159343500368fa085ccd964b';
      final kind = 1;

      // Encode with all fields
      final nprofile = Utils.encodeShareableIdentifier(
        ProfileInput(
            pubkey: pubkey, relays: relays, author: author, kind: kind),
      );

      // Decode and verify all fields
      final decoded = Utils.decodeShareableIdentifier(nprofile);
      expect(decoded, isA<ProfileData>());
      expect((decoded as ProfileData).pubkey, equals(pubkey));
      expect(decoded.relays, equals(relays));
      expect(decoded.author, equals(author));
      expect(decoded.kind, equals(kind));
    });

    test('should throw exception for invalid format', () {
      expect(
        () => Utils.decodeShareableIdentifier('invalid-format'),
        throwsException,
      );
    });

    test('should handle empty nprofile', () {
      expect(
        () => Utils.decodeShareableIdentifier(''),
        throwsException,
      );
    });

    test('should handle malformed bech32', () {
      expect(
        () => Utils.decodeShareableIdentifier('nprofile1invalid'),
        throwsException,
      );
    });
  });

  group('Simple NIP-19 Encoding/Decoding', () {
    test('should encode and decode npub', () {
      final pubkey =
          '7f177706ad6e0aea75a9e3345d9ffdae67676faff249be657b596375e1ced391';
      final npub = Utils.encodeShareableIdentifier(NpubInput(value: pubkey));
      expect(npub.startsWith('npub'), isTrue);
      final decoded = Utils.decodeShareableIdentifier(npub);
      expect(decoded, isA<ProfileData>());
      expect((decoded as ProfileData).pubkey, equals(pubkey));
    });

    test('should encode and decode nsec', () {
      final privateKey =
          '7f177706ad6e0aea75a9e3345d9ffdae67676faff249be657b596375e1ced391';
      final nsec =
          Utils.encodeShareableIdentifier(NsecInput(value: privateKey));
      expect(nsec.startsWith('nsec'), isTrue);
      final decoded = Utils.decodeShareableToString(nsec);
      expect(decoded, equals(privateKey));
    });

    test('should encode and decode note', () {
      final eventId =
          'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1';
      final note = Utils.encodeShareableIdentifier(NoteInput(value: eventId));
      expect(note.startsWith('note'), isTrue);
      final decoded = Utils.decodeShareableIdentifier(note);
      expect(decoded, isA<EventData>());
      expect((decoded as EventData).eventId, equals(eventId));
    });

    test('should encode simple string with explicit type', () {
      final eventId =
          'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1';
      final note = Utils.encodeShareableFromString(eventId, type: 'note');

      expect(note.startsWith('note'), isTrue);
      expect(Utils.decodeShareableToString(note), equals(eventId));
    });

    test('should return already encoded strings as-is', () {
      final npub =
          'npub1qythwumn8ghj7un9d3shjtnswf5k6ctv9ehx2ap0qyvhwumn8ghj7urjv4kkjatd9ec8y6tdv9kzumn9wshsz8rhwden5te0wfjkccte9e3xjarrda5kuurpwf4jucm0d5hsqgrlzamsdttwpt48t20rx3welldwvankltljfxlx276evd67rnknjy2t5aec';
      final result = Utils.encodeShareableFromString(npub, type: 'npub');

      expect(result, equals(npub));
    });

    test('should throw exception for unknown type', () {
      expect(
        () => Utils.encodeShareableFromString('test', type: 'unknown'),
        throwsException,
      );
    });
  });

  group('encodeShareableFromString type coverage', () {
    test('should encode nsec type with raw hex value', () {
      final privateKey =
          '5f1df7a68e4b2a7c8c4b83c4d4e5f3c2a9b8c7d6e5f4c3b2a1b2c3d4e5f6a7b8';
      final nsec = Utils.encodeShareableFromString(privateKey, type: 'nsec');

      expect(nsec.startsWith('nsec'), isTrue);
      expect(Utils.decodeShareableToString(nsec), equals(privateKey));
    });

    test('should encode npub type with raw hex value', () {
      final pubkey =
          '7f177706ad6e0aea75a9e3345d9ffdae67676faff249be657b596375e1ced391';
      final npub = Utils.encodeShareableFromString(pubkey, type: 'npub');

      expect(npub.startsWith('npub'), isTrue);
      expect(Utils.decodeShareableToString(npub), equals(pubkey));
    });

    test('should encode note type with raw hex value', () {
      final eventId =
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
      final note = Utils.encodeShareableFromString(eventId, type: 'note');

      expect(note.startsWith('note'), isTrue);
      expect(Utils.decodeShareableToString(note), equals(eventId));
    });

    test('should encode nprofile type with raw hex value', () {
      final pubkey =
          '83e818dfbeccea56b0f551576b3fd39a7a50e1d8159343500368fa085ccd964b';
      final nprofile =
          Utils.encodeShareableFromString(pubkey, type: 'nprofile');

      expect(nprofile.startsWith('nprofile'), isTrue);
      expect(Utils.decodeShareableToString(nprofile), equals(pubkey));
    });

    test('should encode nevent type with raw hex value', () {
      final eventId =
          'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';
      final nevent = Utils.encodeShareableFromString(eventId, type: 'nevent');

      expect(nevent.startsWith('nevent'), isTrue);
      expect(Utils.decodeShareableToString(nevent), equals(eventId));
    });

    test('should handle all types when value is already encoded', () {
      // Test that all types return the value as-is when already encoded
      final types = ['nsec', 'npub', 'note', 'nprofile', 'nevent'];
      final encodedValues = [
        'nsec1test',
        'npub1test',
        'note1test',
        'nprofile1test',
        'nevent1test'
      ];

      for (int i = 0; i < types.length; i++) {
        final result =
            Utils.encodeShareableFromString(encodedValues[i], type: types[i]);
        expect(result, equals(encodedValues[i]),
            reason: 'Failed for type ${types[i]}');
      }
    });
  });

  group('NIP-21 URI Handling', () {
    test('should handle nostr: URIs', () {
      final pubkey =
          '7f177706ad6e0aea75a9e3345d9ffdae67676faff249be657b596375e1ced391';
      final npub = Utils.encodeShareableFromString(pubkey, type: 'npub');
      final nostrUri = 'nostr:$npub';

      final decoded = Utils.decodeShareableToString(nostrUri);
      expect(decoded, equals(pubkey));
    });

    test('should handle nostr: URIs with complex formats', () {
      final nprofile =
          'nprofile1qythwumn8ghj7un9d3shjtnswf5k6ctv9ehx2ap0qyvhwumn8ghj7urjv4kkjatd9ec8y6tdv9kzumn9wshsz8rhwden5te0wfjkccte9e3xjarrda5kuurpwf4jucm0d5hsqgrlzamsdttwpt48t20rx3welldwvankltljfxlx276evd67rnknjy2t5aec';
      final nostrUri = 'nostr:$nprofile';

      final decoded = Utils.decodeShareableToString(nostrUri);
      expect(
          decoded,
          equals(
              '7f177706ad6e0aea75a9e3345d9ffdae67676faff249be657b596375e1ced391'));
    });
  });

  group('NIP-05 Decoding', () {
    test('should decode valid NIP-05 identifier', () async {
      // This test would require a mock HTTP server or real NIP-05 endpoint
      // For now, we'll test the error handling
      expect(
        () => Utils.decodeNip05('invalid-format'),
        throwsException,
      );
    });

    test('should throw exception for invalid NIP-05 format', () async {
      expect(
        () => Utils.decodeNip05('invalid'),
        throwsException,
      );
    });

    test('should throw exception for malformed NIP-05', () async {
      expect(
        () => Utils.decodeNip05('user@domain@extra'),
        throwsException,
      );
    });
  });
}

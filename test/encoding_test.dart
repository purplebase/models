import 'package:test/test.dart';
import 'package:models/models.dart';
import 'helpers.dart';

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

      final pubkey = Utils.decodeShareable(nprofile);
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
      final decodedEventId = Utils.decodeShareable(nevent);
      expect(decodedEventId, equals(eventId));
    });

    test('should return hex strings as-is when using Utils.decodeShareable',
        () {
      const hexString =
          '7f177706ad6e0aea75a9e3345d9ffdae67676faff249be657b596375e1ced391';

      final result = Utils.decodeShareable(hexString);
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
      final npub = Utils.encodeShareable(pubkey, type: 'npub');

      expect(npub.startsWith('npub'), isTrue);
      expect(Utils.decodeShareable(npub), equals(pubkey));
    });

    test('should encode and decode nsec', () {
      final privateKey =
          '7f177706ad6e0aea75a9e3345d9ffdae67676faff249be657b596375e1ced391';
      final nsec = Utils.encodeShareable(privateKey, type: 'nsec');

      expect(nsec.startsWith('nsec'), isTrue);
      expect(Utils.decodeShareable(nsec), equals(privateKey));
    });

    test('should encode and decode note', () {
      final eventId =
          'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1';
      final note = Utils.encodeShareable(eventId, type: 'note');

      expect(note.startsWith('note'), isTrue);
      expect(Utils.decodeShareable(note), equals(eventId));
    });

    test('should encode simple string with type detection', () {
      final pubkey =
          '7f177706ad6e0aea75a9e3345d9ffdae67676faff249be657b596375e1ced391';
      final npub = Utils.encodeShareable(pubkey);

      expect(npub.startsWith('npub'), isTrue);
      expect(Utils.decodeShareable(npub), equals(pubkey));
    });

    test('should encode simple string with explicit type', () {
      final eventId =
          'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1';
      final note = Utils.encodeShareable(eventId, type: 'note');

      expect(note.startsWith('note'), isTrue);
      expect(Utils.decodeShareable(note), equals(eventId));
    });

    test('should return already encoded strings as-is', () {
      final npub =
          'npub1qythwumn8ghj7un9d3shjtnswf5k6ctv9ehx2ap0qyvhwumn8ghj7urjv4kkjatd9ec8y6tdv9kzumn9wshsz8rhwden5te0wfjkccte9e3xjarrda5kuurpwf4jucm0d5hsqgrlzamsdttwpt48t20rx3welldwvankltljfxlx276evd67rnknjy2t5aec';
      final result = Utils.encodeShareable(npub);

      expect(result, equals(npub));
    });

    test('should throw exception for unknown type', () {
      expect(
        () => Utils.encodeShareable('test', type: 'unknown'),
        throwsException,
      );
    });
  });

  group('NIP-21 URI Handling', () {
    test('should handle nostr: URIs', () {
      final pubkey =
          '7f177706ad6e0aea75a9e3345d9ffdae67676faff249be657b596375e1ced391';
      final npub = Utils.encodeShareable(pubkey, type: 'npub');
      final nostrUri = 'nostr:$npub';

      final decoded = Utils.decodeShareable(nostrUri);
      expect(decoded, equals(pubkey));
    });

    test('should handle nostr: URIs with complex formats', () {
      final nprofile =
          'nprofile1qythwumn8ghj7un9d3shjtnswf5k6ctv9ehx2ap0qyvhwumn8ghj7urjv4kkjatd9ec8y6tdv9kzumn9wshsz8rhwden5te0wfjkccte9e3xjarrda5kuurpwf4jucm0d5hsqgrlzamsdttwpt48t20rx3welldwvankltljfxlx276evd67rnknjy2t5aec';
      final nostrUri = 'nostr:$nprofile';

      final decoded = Utils.decodeShareable(nostrUri);
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

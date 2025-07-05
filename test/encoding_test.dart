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

      final pubkey = ShareableIdentifiers.pubkeyFromNprofile(nprofile);
      expect(pubkey, equals(expectedPubkey));
    });

    test('should roundtrip encode and decode nprofile with pubkey only', () {
      final pubkey = nielPubkey;

      // Encode pubkey to nprofile
      final nprofile = ShareableIdentifiers.encode(
        ProfileInput(pubkey: pubkey),
      );

      // Decode nprofile back to pubkey
      final decoded = ShareableIdentifiers.decode(nprofile);
      expect(decoded, isA<ProfileData>());
      final decodedPubkey = (decoded as ProfileData).pubkey;

      expect(decodedPubkey, equals(pubkey));
      expect(nprofile.startsWith('nprofile'), isTrue);
    });

    test('should roundtrip encode and decode nprofile with relays', () {
      final pubkey = verbirichaPubkey;
      final relays = ['wss://relay.damus.io', 'wss://relay.nostr.band'];

      // Encode pubkey with relays to nprofile
      final nprofile = ShareableIdentifiers.encode(
        ProfileInput(pubkey: pubkey, relays: relays),
      );

      // Decode nprofile back
      final decoded = ShareableIdentifiers.decode(nprofile);
      expect(decoded, isA<ProfileData>());
      final decodedPubkey = (decoded as ProfileData).pubkey;

      expect(decodedPubkey, equals(pubkey));
      expect(decoded.relays, equals(relays));
      expect(nprofile.startsWith('nprofile'), isTrue);
    });

    test('should roundtrip encode and decode nevent', () {
      final eventId =
          'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1';
      final author = franzapPubkey;
      final relays = ['wss://relay.primal.net'];

      // Encode event to nevent
      final nevent = ShareableIdentifiers.encode(
        EventInput(eventId: eventId, relays: relays, author: author),
      );

      // Decode nevent back
      final decoded = ShareableIdentifiers.decode(nevent);
      expect(decoded, isA<EventData>());
      final decodedEventId = (decoded as EventData).eventId;

      expect(decodedEventId, equals(eventId));
      expect(decoded.author, equals(author));
      expect(decoded.relays, equals(relays));
      expect(nevent.startsWith('nevent'), isTrue);
    });

    test('should roundtrip encode and decode naddr', () {
      final identifier =
          '30023:a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be:verbiricha';
      final author = nielPubkey;
      final kind = 30023;
      final relays = ['wss://relay.damus.io'];

      // Encode address to naddr
      final naddr = ShareableIdentifiers.encode(
        AddressInput(
            identifier: identifier, relays: relays, author: author, kind: kind),
      );

      // Decode naddr back
      final decoded = ShareableIdentifiers.decode(naddr);
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
      final nprofile = ShareableIdentifiers.encode(
        ProfileInput(pubkey: pubkey, relays: relays),
      );

      // Decode and verify all relays
      final decoded = ShareableIdentifiers.decode(nprofile);
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
      final nprofile = ShareableIdentifiers.encode(
        ProfileInput(
            pubkey: pubkey, relays: relays, author: author, kind: kind),
      );

      // Decode and verify all fields
      final decoded = ShareableIdentifiers.decode(nprofile);
      expect(decoded, isA<ProfileData>());
      expect((decoded as ProfileData).pubkey, equals(pubkey));
      expect(decoded.relays, equals(relays));
      expect(decoded.author, equals(author));
      expect(decoded.kind, equals(kind));
    });

    test('should throw exception for invalid format', () {
      expect(
        () => ShareableIdentifiers.decode('invalid-format'),
        throwsException,
      );
    });

    test('should handle empty nprofile', () {
      expect(
        () => ShareableIdentifiers.decode(''),
        throwsException,
      );
    });

    test('should handle malformed bech32', () {
      expect(
        () => ShareableIdentifiers.decode('nprofile1invalid'),
        throwsException,
      );
    });
  });
}

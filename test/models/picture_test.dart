import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    storage =
        container.read(storageNotifierProvider.notifier)
            as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.cancel();
    await storage.clear();
    container.dispose();
  });

  group('Picture', () {
    test('from/to partial model', () async {
      final picture = PartialPicture(
        imageUrl: 'https://example.com/image.jpg',
        description: 'Beautiful sunset at the beach',
        altText: 'A colorful sunset over ocean waves',
        hashtags: {'sunset', 'beach', 'photography'},
        location: 'Malibu Beach, CA',
        mimeType: 'image/jpeg',
        fileSize: 1024576,
        dimensions: '1920x1080',
        imageHash:
            'abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
      ).dummySign(nielPubkey);

      expect(picture.description, 'Beautiful sunset at the beach');
      expect(picture.imageUrl, 'https://example.com/image.jpg');
      expect(picture.altText, 'A colorful sunset over ocean waves');
      expect(picture.hashtags, {'sunset', 'beach', 'photography'});
      expect(picture.location, 'Malibu Beach, CA');
      expect(picture.mimeType, 'image/jpeg');
      expect(picture.fileSize, 1024576);
      expect(picture.dimensions, '1920x1080');
      expect(picture.width, 1920);
      expect(picture.height, 1080);
      expect(
        picture.imageHash,
        'abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
      );
      expect(picture.hasLocation, true);
      expect(picture.hasAltText, true);

      final partial = picture.toPartial() as PartialPicture;
      expect(partial.description, 'Beautiful sunset at the beach');
      expect(partial.imageUrl, 'https://example.com/image.jpg');
      expect(partial.hashtags, {'sunset', 'beach', 'photography'});
    });

    test('withDimensions constructor', () {
      final picture = PartialPicture.withDimensions(
        imageUrl: 'https://example.com/photo.png',
        width: 800,
        height: 600,
        description: 'Test photo',
        mimeType: 'image/png',
      ).dummySign(nielPubkey);

      expect(picture.imageUrl, 'https://example.com/photo.png');
      expect(picture.dimensions, '800x600');
      expect(picture.width, 800);
      expect(picture.height, 600);
      expect(picture.description, 'Test photo');
      expect(picture.mimeType, 'image/png');
    });

    test('minimal picture', () {
      final picture = PartialPicture(
        imageUrl: 'https://example.com/minimal.jpg',
      ).dummySign(nielPubkey);

      expect(picture.imageUrl, 'https://example.com/minimal.jpg');
      expect(picture.description, '');
      expect(picture.hashtags, isEmpty);
      expect(picture.hasLocation, false);
      expect(picture.hasAltText, false);
      expect(picture.width, null);
      expect(picture.height, null);
    });

    test('multiple image URLs', () {
      final partial = PartialPicture(
        imageUrl: 'https://example.com/original.jpg',
      );

      // Add alternative URLs
      partial.addImageUrl('https://example.com/thumb.jpg');
      partial.addImageUrl('https://example.com/medium.jpg');

      final picture = partial.dummySign(nielPubkey);

      expect(picture.imageUrl, 'https://example.com/original.jpg');
      expect(picture.allImageUrls, {
        'https://example.com/original.jpg',
        'https://example.com/thumb.jpg',
        'https://example.com/medium.jpg',
      });
      expect(picture.altImageUrls, {
        'https://example.com/thumb.jpg',
        'https://example.com/medium.jpg',
      });
    });

    test('partial model methods', () {
      final partial = PartialPicture(imageUrl: 'https://example.com/test.jpg');

      // Test basic setters
      partial.description = 'Updated description';
      partial.altText = 'Updated alt text';
      partial.location = 'New Location';
      partial.mimeType = 'image/webp';
      partial.fileSize = 2048;
      partial.dimensions = '1024x768';
      partial.imageHash = 'newhash123';

      expect(partial.description, 'Updated description');
      expect(partial.altText, 'Updated alt text');
      expect(partial.location, 'New Location');
      expect(partial.mimeType, 'image/webp');
      expect(partial.fileSize, 2048);
      expect(partial.dimensions, '1024x768');
      expect(partial.imageHash, 'newhash123');

      // Test hashtag management
      partial.addHashtag('nature');
      partial.addHashtag('photography');
      expect(partial.hashtags, {'nature', 'photography'});

      partial.removeHashtag('nature');
      expect(partial.hashtags, {'photography'});

      partial.hashtags = {'art', 'digital'};
      expect(partial.hashtags, {'art', 'digital'});

      // Test image URL management
      partial.addImageUrl('https://example.com/alt1.jpg');
      partial.addImageUrl('https://example.com/alt2.jpg');
      expect(partial.allImageUrls.length, 3); // original + 2 alternatives

      partial.removeImageUrl('https://example.com/alt1.jpg');
      expect(partial.allImageUrls.length, 2);
    });

    test('dimension parsing edge cases', () {
      // Valid dimensions
      final picture1 = PartialPicture(
        imageUrl: 'https://example.com/test.jpg',
        dimensions: '1920x1080',
      ).dummySign(nielPubkey);
      expect(picture1.width, 1920);
      expect(picture1.height, 1080);

      // Invalid dimensions
      final picture2 = PartialPicture(
        imageUrl: 'https://example.com/test.jpg',
        dimensions: 'invalid',
      ).dummySign(nielPubkey);
      expect(picture2.width, null);
      expect(picture2.height, null);

      // Malformed dimensions
      final picture3 = PartialPicture(
        imageUrl: 'https://example.com/test.jpg',
        dimensions: '1920x',
      ).dummySign(nielPubkey);
      expect(picture3.width, 1920);
      expect(picture3.height, null);

      // No dimensions
      final picture4 = PartialPicture(
        imageUrl: 'https://example.com/test.jpg',
      ).dummySign(nielPubkey);
      expect(picture4.width, null);
      expect(picture4.height, null);
    });

    test('geohash location', () {
      final partial = PartialPicture(imageUrl: 'https://example.com/geo.jpg');
      partial.geohash = 'dr5r7p3w';
      final picture = partial.dummySign(nielPubkey);

      expect(picture.geohash, 'dr5r7p3w');
      expect(picture.hasLocation, true);
      expect(picture.location, null); // Only geohash, no text location
    });

    test('relationships', () async {
      // Create related data
      final picture = PartialPicture(
        imageUrl: 'https://example.com/social.jpg',
        description: 'A social media picture',
      ).dummySign(nielPubkey);

      final note = PartialNote('Check out this picture!').dummySign(nielPubkey);
      final reaction = PartialReaction(
        content: '❤️',
        reactedOn: picture,
      ).dummySign(nielPubkey);

      await storage.save({picture, note, reaction});

      // Test relationships exist but may be empty for this simple test
      expect(picture.referencingNotes, isNotNull);
      expect(picture.reactions, isNotNull);
      expect(picture.comments, isNotNull);
    });

    test('event kind and structure', () {
      final picture = PartialPicture(
        imageUrl: 'https://example.com/structure.jpg',
        description: 'Test structure',
        hashtags: {'test'},
        location: 'Test Location',
      ).dummySign(nielPubkey);

      expect(picture.event.kind, 20);
      expect(picture.event.content, 'Test structure');
      expect(
        picture.event.getTagSetValues('url'),
        contains('https://example.com/structure.jpg'),
      );
      expect(picture.event.getTagSetValues('t'), {'test'});
      expect(picture.event.getFirstTagValue('location'), 'Test Location');
    });

    test('empty content handling', () {
      final picture = PartialPicture(
        imageUrl: 'https://example.com/empty.jpg',
        // No description provided
      ).dummySign(nielPubkey);

      expect(picture.description, ''); // Should be empty string, not null

      final partial = picture.toPartial() as PartialPicture;
      expect(
        partial.description,
        null,
      ); // Partial should return null for empty content
    });
  });
}

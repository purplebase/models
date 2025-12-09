import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
    ref = container.read(refProvider);
    storage =
        container.read(storageNotifierProvider.notifier) as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.clear();
    container.dispose();
  });

  group('Video (kind 21)', () {
    test('video creation and serialization', () async {
      // Create related models first
      final authorProfile = PartialProfile(
        name: 'Video Creator',
      ).dummySign(nielPubkey);
      await storage.save({authorProfile});

      final video = PartialVideo(
        videoUrl: 'https://example.com/video.mp4',
        description: 'Amazing sunset timelapse captured in 4K',
        title: 'Sunset Timelapse',
        altText: 'Time-lapse video of a colorful sunset over mountains',
        hashtags: {'sunset', 'timelapse', 'nature', '4k'},
        location: 'Mount Fuji, Japan',
        mimeType: 'video/mp4',
        fileSize: 125829120, // ~120MB
        duration: 180, // 3 minutes
        dimensions: '3840x2160',
        videoHash:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
        summary: 'Beautiful 3-minute sunset timelapse in 4K resolution',
      ).dummySign(nielPubkey);

      await storage.save({video});

      // Test properties
      expect(video.description, 'Amazing sunset timelapse captured in 4K');
      expect(video.videoUrl, 'https://example.com/video.mp4');
      expect(video.title, 'Sunset Timelapse');
      expect(
        video.altText,
        'Time-lapse video of a colorful sunset over mountains',
      );
      expect(
        video.hashtags,
        containsAll(['sunset', 'timelapse', 'nature', '4k']),
      );
      expect(video.location, 'Mount Fuji, Japan');
      expect(video.mimeType, 'video/mp4');
      expect(video.fileSize, 125829120);
      expect(video.duration, 180);
      expect(video.dimensions, '3840x2160');
      expect(video.width, 3840);
      expect(video.height, 2160);
      expect(
        video.videoHash,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(video.thumbnailUrl, 'https://example.com/thumbnail.jpg');
      expect(
        video.summary,
        'Beautiful 3-minute sunset timelapse in 4K resolution',
      );
      expect(video.hasLocation, true);
      expect(video.hasAltText, true);
      expect(video.hasThumbnail, true);

      // Test relationships
      expect(video.author.value!.pubkey, nielPubkey);

      // Test serialization roundtrip
      final video2 = Video.fromMap(video.toMap(), ref);
      expect(video.toMap(), video2.toMap());
    });

    test('video with dimensions constructor', () async {
      final video = PartialVideo.withDimensions(
        videoUrl: 'https://example.com/hd-video.mp4',
        width: 1920,
        height: 1080,
        description: 'HD landscape video',
        title: 'Landscape Beauty',
      ).dummySign();

      await storage.save({video});

      expect(video.dimensions, '1920x1080');
      expect(video.width, 1920);
      expect(video.height, 1080);
      expect(video.videoUrl, 'https://example.com/hd-video.mp4');
      expect(video.description, 'HD landscape video');
      expect(video.title, 'Landscape Beauty');
    });

    test('video relationships', () async {
      final video = PartialVideo(
        videoUrl: 'https://example.com/test-video.mp4',
        description: 'Test video for relationships',
      ).dummySign(nielPubkey);

      // Create a comment on this video
      final comment = PartialComment(
        content: 'Great video!',
        rootModel: video,
      ).dummySign();

      await storage.save({video, comment});

      // Test relationships work properly
      final comments = video.comments.toList();
      expect(comments, hasLength(1));
      expect(comments.first.content, 'Great video!');
    });

    test('video partial model setters', () async {
      final partialVideo = PartialVideo(
        videoUrl: 'https://example.com/initial.mp4',
      );

      // Test all setters
      partialVideo.description = 'Updated description';
      partialVideo.videoUrl = 'https://example.com/updated.mp4';
      partialVideo.title = 'Updated Title';
      partialVideo.altText = 'Updated alt text';
      partialVideo.hashtags = {'updated', 'test'};
      partialVideo.location = 'Updated Location';
      partialVideo.mimeType = 'video/webm';
      partialVideo.fileSize = 1000000;
      partialVideo.duration = 60;
      partialVideo.dimensions = '1280x720';
      partialVideo.videoHash = 'newhash123';
      partialVideo.thumbnailUrl = 'https://example.com/new-thumb.jpg';
      partialVideo.summary = 'Updated summary';

      final video = partialVideo.dummySign();
      await storage.save({video});

      expect(video.description, 'Updated description');
      expect(video.videoUrl, 'https://example.com/updated.mp4');
      expect(video.title, 'Updated Title');
      expect(video.altText, 'Updated alt text');
      expect(video.hashtags, containsAll(['updated', 'test']));
      expect(video.location, 'Updated Location');
      expect(video.mimeType, 'video/webm');
      expect(video.fileSize, 1000000);
      expect(video.duration, 60);
      expect(video.dimensions, '1280x720');
      expect(video.videoHash, 'newhash123');
      expect(video.thumbnailUrl, 'https://example.com/new-thumb.jpg');
      expect(video.summary, 'Updated summary');
    });

    test('video hashtag management', () async {
      final partialVideo = PartialVideo(
        videoUrl: 'https://example.com/hashtag-test.mp4',
        hashtags: {'initial', 'test'},
      );

      // Test add/remove hashtag methods
      partialVideo.addHashtag('new');
      partialVideo.addHashtag('tag');
      expect(
        partialVideo.hashtags,
        containsAll(['initial', 'test', 'new', 'tag']),
      );

      partialVideo.removeHashtag('initial');
      expect(partialVideo.hashtags, isNot(contains('initial')));
      expect(partialVideo.hashtags, containsAll(['test', 'new', 'tag']));

      final video = partialVideo.dummySign();
      await storage.save({video});
    });

    test('video URL management', () async {
      final partialVideo = PartialVideo(
        videoUrl: 'https://example.com/primary.mp4',
      );

      // Test URL management
      partialVideo.addVideoUrl('https://example.com/alt1.mp4');
      partialVideo.addVideoUrl('https://example.com/alt2.mp4');

      expect(partialVideo.allVideoUrls, hasLength(3));
      expect(
        partialVideo.allVideoUrls,
        contains('https://example.com/primary.mp4'),
      );
      expect(
        partialVideo.allVideoUrls,
        contains('https://example.com/alt1.mp4'),
      );
      expect(
        partialVideo.allVideoUrls,
        contains('https://example.com/alt2.mp4'),
      );

      partialVideo.removeVideoUrl('https://example.com/alt1.mp4');
      expect(partialVideo.allVideoUrls, hasLength(2));
      expect(
        partialVideo.allVideoUrls,
        isNot(contains('https://example.com/alt1.mp4')),
      );

      final video = partialVideo.dummySign();
      await storage.save({video});
    });
  });

  group('ShortFormPortraitVideo (kind 22)', () {
    test('short form portrait video creation and serialization', () async {
      // Create related models first
      final authorProfile = PartialProfile(
        name: 'Content Creator',
      ).dummySign(nielPubkey);
      await storage.save({authorProfile});

      final shortVideo = PartialShortFormPortraitVideo(
        videoUrl: 'https://example.com/short-video.mp4',
        description: 'Quick dance video! 💃',
        title: 'Dance Challenge',
        altText: 'Person dancing to upbeat music in portrait format',
        hashtags: {'dance', 'shortform', 'viral', 'challenge'},
        location: 'TikTok Studio',
        mimeType: 'video/mp4',
        fileSize: 5242880, // ~5MB
        duration: 15, // 15 seconds
        dimensions: '1080x1920', // Portrait orientation
        videoHash: 'shortformhash123',
        thumbnailUrl: 'https://example.com/dance-thumb.jpg',
        summary: 'Fun 15-second dance challenge video',
      ).dummySign(nielPubkey);

      await storage.save({shortVideo});

      // Test properties
      expect(shortVideo.description, 'Quick dance video! 💃');
      expect(shortVideo.videoUrl, 'https://example.com/short-video.mp4');
      expect(shortVideo.title, 'Dance Challenge');
      expect(
        shortVideo.altText,
        'Person dancing to upbeat music in portrait format',
      );
      expect(
        shortVideo.hashtags,
        containsAll(['dance', 'shortform', 'viral', 'challenge']),
      );
      expect(shortVideo.location, 'TikTok Studio');
      expect(shortVideo.mimeType, 'video/mp4');
      expect(shortVideo.fileSize, 5242880);
      expect(shortVideo.duration, 15);
      expect(shortVideo.dimensions, '1080x1920');
      expect(shortVideo.width, 1080);
      expect(shortVideo.height, 1920);
      expect(shortVideo.isPortrait, true); // Height > width
      expect(shortVideo.videoHash, 'shortformhash123');
      expect(shortVideo.thumbnailUrl, 'https://example.com/dance-thumb.jpg');
      expect(shortVideo.summary, 'Fun 15-second dance challenge video');
      expect(shortVideo.hasLocation, true);
      expect(shortVideo.hasAltText, true);
      expect(shortVideo.hasThumbnail, true);

      // Test relationships
      expect(shortVideo.author.value!.pubkey, nielPubkey);

      // Test serialization roundtrip
      final shortVideo2 = ShortFormPortraitVideo.fromMap(
        shortVideo.toMap(),
        ref,
      );
      expect(shortVideo.toMap(), shortVideo2.toMap());
    });

    test('portrait orientation detection', () async {
      // Test portrait video (height > width)
      final portraitVideo = PartialShortFormPortraitVideo.withDimensions(
        videoUrl: 'https://example.com/portrait.mp4',
        width: 720,
        height: 1280,
      ).dummySign();

      expect(portraitVideo.isPortrait, true);

      // Test landscape video (width > height) - shouldn't really be used for this kind but testing the logic
      final landscapeVideo = PartialShortFormPortraitVideo.withDimensions(
        videoUrl: 'https://example.com/landscape.mp4',
        width: 1280,
        height: 720,
      ).dummySign();

      expect(landscapeVideo.isPortrait, false);

      // Test square video (width == height)
      final squareVideo = PartialShortFormPortraitVideo.withDimensions(
        videoUrl: 'https://example.com/square.mp4',
        width: 720,
        height: 720,
      ).dummySign();

      expect(squareVideo.isPortrait, false);

      await storage.save({portraitVideo, landscapeVideo, squareVideo});
    });

    test('short form video relationships', () async {
      final shortVideo = PartialShortFormPortraitVideo(
        videoUrl: 'https://example.com/viral-video.mp4',
        description: 'Going viral! 🚀',
      ).dummySign(nielPubkey);

      // Create a comment on this video
      final comment = PartialComment(
        content: 'This is amazing! 🔥',
        rootModel: shortVideo,
      ).dummySign();

      await storage.save({shortVideo, comment});

      // Test relationships work properly
      final comments = shortVideo.comments.toList();
      expect(comments, hasLength(1));
      expect(comments.first.content, 'This is amazing! 🔥');
    });

    test('short form video partial model setters', () async {
      final partialShortVideo = PartialShortFormPortraitVideo(
        videoUrl: 'https://example.com/initial-short.mp4',
      );

      // Test all setters work the same as regular video
      partialShortVideo.description = 'Updated short video description';
      partialShortVideo.videoUrl = 'https://example.com/updated-short.mp4';
      partialShortVideo.title = 'Updated Short Title';
      partialShortVideo.altText = 'Updated short video alt text';
      partialShortVideo.hashtags = {'updated', 'short', 'viral'};
      partialShortVideo.location = 'Updated Studio';
      partialShortVideo.mimeType = 'video/webm';
      partialShortVideo.fileSize = 2000000;
      partialShortVideo.duration = 30;
      partialShortVideo.dimensions = '720x1280';
      partialShortVideo.videoHash = 'updatedshorthash';
      partialShortVideo.thumbnailUrl =
          'https://example.com/updated-short-thumb.jpg';
      partialShortVideo.summary = 'Updated short video summary';

      final shortVideo = partialShortVideo.dummySign();
      await storage.save({shortVideo});

      expect(shortVideo.description, 'Updated short video description');
      expect(shortVideo.videoUrl, 'https://example.com/updated-short.mp4');
      expect(shortVideo.title, 'Updated Short Title');
      expect(shortVideo.altText, 'Updated short video alt text');
      expect(shortVideo.hashtags, containsAll(['updated', 'short', 'viral']));
      expect(shortVideo.location, 'Updated Studio');
      expect(shortVideo.mimeType, 'video/webm');
      expect(shortVideo.fileSize, 2000000);
      expect(shortVideo.duration, 30);
      expect(shortVideo.dimensions, '720x1280');
      expect(shortVideo.videoHash, 'updatedshorthash');
      expect(
        shortVideo.thumbnailUrl,
        'https://example.com/updated-short-thumb.jpg',
      );
      expect(shortVideo.summary, 'Updated short video summary');
    });
  });

  group('Video Edge Cases', () {
    test('video with minimal data', () async {
      final video = PartialVideo(
        videoUrl: 'https://example.com/minimal.mp4',
      ).dummySign();

      await storage.save({video});

      expect(video.videoUrl, 'https://example.com/minimal.mp4');
      expect(video.description, isEmpty);
      expect(video.title, isNull);
      expect(video.altText, isNull);
      expect(video.hashtags, isEmpty);
      expect(video.location, isNull);
      expect(video.mimeType, isNull);
      expect(video.fileSize, isNull);
      expect(video.duration, isNull);
      expect(video.dimensions, isNull);
      expect(video.width, isNull);
      expect(video.height, isNull);
      expect(video.videoHash, isNull);
      expect(video.thumbnailUrl, isNull);
      expect(video.summary, isNull);
      expect(video.hasLocation, false);
      expect(video.hasAltText, false);
      expect(video.hasThumbnail, false);
    });

    test('video with empty content', () async {
      final video = PartialVideo(
        videoUrl: 'https://example.com/empty.mp4',
        description: '',
      ).dummySign();

      await storage.save({video});

      expect(video.description, isEmpty);
    });

    test('video with malformed dimensions', () async {
      final video = PartialVideo(
        videoUrl: 'https://example.com/malformed.mp4',
        dimensions: 'invalid',
      ).dummySign();

      await storage.save({video});

      expect(video.dimensions, 'invalid');
      expect(video.width, isNull);
      expect(video.height, isNull);
    });

    test('video with partial dimensions', () async {
      final video = PartialVideo(
        videoUrl: 'https://example.com/partial.mp4',
        dimensions: '1920x', // Missing height
      ).dummySign();

      await storage.save({video});

      expect(video.dimensions, '1920x');
      expect(video.width, 1920);
      expect(video.height, isNull);
    });

    test('video with invalid numeric values', () async {
      final partialVideo = PartialVideo(
        videoUrl: 'https://example.com/invalid.mp4',
      );

      // Set invalid values via tag manipulation
      partialVideo.event.setTagValue('size', 'not-a-number');
      partialVideo.event.setTagValue('duration', 'invalid');

      final video = partialVideo.dummySign();
      await storage.save({video});

      expect(video.fileSize, isNull);
      expect(video.duration, isNull);
    });

    test('imeta URL parsing (NIP-71)', () {
      // Create a video event with imeta tags instead of simple url tags
      final eventData = {
        'id': 'test123',
        'pubkey': nielPubkey,
        'created_at': 1671217411,
        'kind': 21,
        'content': 'Test video with imeta tags',
        'tags': [
          ['title', 'Test Video'],
          [
            'imeta',
            'url https://videos.example.com/video-1080p.mp4',
            'm video/mp4',
            'dim 1920x1080',
            'x 3093509d1e0bc604ff60cb9286f4cd7c781553bc8991937befaacfdc28ec5cdc',
            'image https://videos.example.com/thumb.jpg',
          ],
          [
            'imeta',
            'url https://videos.example.com/video-720p.mp4',
            'm video/mp4',
            'dim 1280x720',
            'x e1d4f808dae475ed32fb23ce52ef8ac82e3cc760702fca10d62d382d2da3697d',
          ],
        ],
        'sig': 'testsig123',
      };

      final video = Video.fromMap(eventData, ref);

      // Test that imeta URLs are parsed correctly
      expect(video.videoUrl, 'https://videos.example.com/video-1080p.mp4');
      expect(video.allVideoUrls, {
        'https://videos.example.com/video-1080p.mp4',
        'https://videos.example.com/video-720p.mp4',
      });
    });

    test('imeta fallback to url tags', () {
      // Create a video with both imeta and url tags - imeta should take precedence
      final eventData = {
        'id': 'test123',
        'pubkey': nielPubkey,
        'created_at': 1671217411,
        'kind': 21,
        'content': 'Test video with both imeta and url tags',
        'tags': [
          ['title', 'Mixed Video'],
          ['url', 'https://old-style.com/video.mp4'],
          ['imeta', 'url https://new-style.com/video.mp4', 'm video/mp4'],
        ],
        'sig': 'testsig123',
      };

      final video = Video.fromMap(eventData, ref);

      // imeta URL should take precedence
      expect(video.videoUrl, 'https://new-style.com/video.mp4');
      expect(video.allVideoUrls, {
        'https://new-style.com/video.mp4',
        'https://old-style.com/video.mp4',
      });
    });

    test('fallback to url tags when no imeta', () {
      // Create a video with only old-style url tags
      final eventData = {
        'id': 'test123',
        'pubkey': nielPubkey,
        'created_at': 1671217411,
        'kind': 21,
        'content': 'Test video with only url tags',
        'tags': [
          ['title', 'Legacy Video'],
          ['url', 'https://old-style.com/video1.mp4'],
          ['url', 'https://old-style.com/video2.mp4'],
        ],
        'sig': 'testsig123',
      };

      final video = Video.fromMap(eventData, ref);

      // Should fall back to url tags
      expect(video.videoUrl, 'https://old-style.com/video1.mp4');
      expect(video.allVideoUrls, {
        'https://old-style.com/video1.mp4',
        'https://old-style.com/video2.mp4',
      });
    });
  });

  group('ShortFormPortraitVideo (kind 22)', () {
    test('imeta URL parsing (NIP-71)', () {
      // Create a short-form video event with imeta tags
      final eventData = {
        'id': 'test456',
        'pubkey': nielPubkey,
        'created_at': 1671217411,
        'kind': 22,
        'content': 'Quick dance video! #dance #shorts',
        'tags': [
          ['title', 'Dance Moves'],
          [
            'imeta',
            'url https://shorts.example.com/dance-1080p.mp4',
            'm video/mp4',
            'dim 1080x1920',
            'x 4186509d1e0bc604ff60cb9286f4cd7c781553bc8991937befaacfdc28ec5cdc',
            'image https://shorts.example.com/dance-thumb.jpg',
          ],
          [
            'imeta',
            'url https://shorts.example.com/dance-720p.mp4',
            'm video/mp4',
            'dim 720x1280',
            'x f2e5f808dae475ed32fb23ce52ef8ac82e3cc760702fca10d62d382d2da3697d',
          ],
        ],
        'sig': 'testsig456',
      };

      final shortVideo = ShortFormPortraitVideo.fromMap(eventData, ref);

      // Test that imeta URLs are parsed correctly
      expect(shortVideo.videoUrl, 'https://shorts.example.com/dance-1080p.mp4');
      expect(shortVideo.allVideoUrls, {
        'https://shorts.example.com/dance-1080p.mp4',
        'https://shorts.example.com/dance-720p.mp4',
      });
    });

    test('imeta fallback to url tags', () {
      // Create a short video with both imeta and url tags
      final eventData = {
        'id': 'test456',
        'pubkey': nielPubkey,
        'created_at': 1671217411,
        'kind': 22,
        'content': 'Test short video with mixed tags',
        'tags': [
          ['title', 'Mixed Short Video'],
          ['url', 'https://old-style.com/short.mp4'],
          ['imeta', 'url https://new-style.com/short.mp4', 'm video/mp4'],
        ],
        'sig': 'testsig456',
      };

      final shortVideo = ShortFormPortraitVideo.fromMap(eventData, ref);

      // imeta URL should take precedence
      expect(shortVideo.videoUrl, 'https://new-style.com/short.mp4');
      expect(shortVideo.allVideoUrls, {
        'https://new-style.com/short.mp4',
        'https://old-style.com/short.mp4',
      });
    });
  });
}

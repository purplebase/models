import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    ref = container.read(refProvider);
    storage =
        container.read(storageNotifierProvider.notifier)
            as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.cancel();
    await storage.clear();
    container.dispose();
  });

  group('VoiceMessage', () {
    test('creates a valid voice message event', () async {
      final voiceMessage = PartialVoiceMessage(
        audioUrl: 'https://example.com/voice.mp3',
        description: 'Test voice message',
        duration: 60,
        transcript: 'Hello, this is a test voice message',
        title: 'Test Voice',
        altText: 'Voice message saying hello',
        hashtags: {'test', 'voice'},
        location: 'New York',
        mimeType: 'audio/mp3',
        fileSize: 1024000,
        audioHash: 'abc123',
        waveform: 'waveform_data',
        summary: 'A test voice message',
      ).dummySign(nielPubkey);

      expect(voiceMessage.event.kind, 1222);
      expect(
        voiceMessage.description,
        'https://example.com/voice.mp3',
      ); // Per NIP-A0: content contains audio URL
      expect(voiceMessage.audioUrl, 'https://example.com/voice.mp3');
      expect(voiceMessage.duration, 60);
      expect(voiceMessage.transcript, 'Hello, this is a test voice message');
      expect(voiceMessage.title, 'Test Voice');
      expect(voiceMessage.altText, 'Voice message saying hello');
      expect(voiceMessage.hashtags, {'test', 'voice'});
      expect(voiceMessage.location, 'New York');
      expect(voiceMessage.mimeType, 'audio/mp3');
      expect(voiceMessage.fileSize, 1024000);
      expect(voiceMessage.audioHash, 'abc123');
      expect(voiceMessage.waveform, 'waveform_data');
      expect(voiceMessage.summary, 'A test voice message');

      // Test formatted duration
      expect(voiceMessage.formattedDuration, '1:00');

      // Test boolean checks
      expect(voiceMessage.hasLocation, true);
      expect(voiceMessage.hasAltText, true);
      expect(voiceMessage.hasTranscript, true);
      expect(voiceMessage.hasWaveform, true);
    });

    test('creates minimal voice message with only required fields', () async {
      final voiceMessage = PartialVoiceMessage(
        audioUrl: 'https://example.com/voice.wav',
      ).dummySign(nielPubkey);

      expect(voiceMessage.event.kind, 1222);
      expect(voiceMessage.audioUrl, 'https://example.com/voice.wav');
      expect(
        voiceMessage.description,
        'https://example.com/voice.wav',
      ); // Per NIP-A0: content contains audio URL
      expect(voiceMessage.duration, null);
      expect(voiceMessage.transcript, null);
      expect(voiceMessage.hasLocation, false);
      expect(voiceMessage.hasAltText, false);
      expect(voiceMessage.hasTranscript, false);
      expect(voiceMessage.hasWaveform, false);
    });

    test('parses voice message from event map', () {
      final eventMap = {
        'id': Utils.generateRandomHex64(),
        'pubkey': Utils.generateRandomHex64(),
        'created_at': 1234567890,
        'kind': 1222,
        'content':
            'https://example.com/voice.mp3', // Per NIP-A0: content must be audio URL
        'tags': [
          ['url', 'https://example.com/voice_alt.ogg'],
          ['x', 'hash123'],
          ['m', 'audio/mp3'],
          ['size', '512000'],
          ['duration', '45'],
          ['transcript', 'Hello world'],
          ['alt', 'Voice saying hello world'],
          ['t', 'greeting'],
          ['t', 'test'],
          ['location', 'San Francisco'],
          ['g', 'geohash123'],
          ['title', 'Greeting Message'],
          ['waveform', 'waveform_data'],
          ['summary', 'A greeting voice message'],
        ],
        'sig': 'signature',
      };

      final voiceMessage = VoiceMessage.fromMap(eventMap, ref);

      expect(
        voiceMessage.description,
        'https://example.com/voice.mp3',
      ); // Per NIP-A0: description returns content (audio URL)
      expect(voiceMessage.audioUrl, 'https://example.com/voice.mp3');
      expect(voiceMessage.allAudioUrls, {
        'https://example.com/voice.mp3',
        'https://example.com/voice_alt.ogg',
      });
      expect(voiceMessage.altAudioUrls, {'https://example.com/voice_alt.ogg'});
      expect(voiceMessage.audioHash, 'hash123');
      expect(voiceMessage.mimeType, 'audio/mp3');
      expect(voiceMessage.fileSize, 512000);
      expect(voiceMessage.duration, 45);
      expect(voiceMessage.transcript, 'Hello world');
      expect(voiceMessage.altText, 'Voice saying hello world');
      expect(voiceMessage.hashtags, {'greeting', 'test'});
      expect(voiceMessage.location, 'San Francisco');
      expect(voiceMessage.geohash, 'geohash123');
      expect(voiceMessage.title, 'Greeting Message');
      expect(voiceMessage.waveform, 'waveform_data');
      expect(voiceMessage.summary, 'A greeting voice message');
      expect(voiceMessage.formattedDuration, '0:45');
    });

    test('handles partial voice message modification', () {
      final partialVoiceMessage = PartialVoiceMessage.fromMap({
        'id': Utils.generateRandomHex64(),
        'pubkey': Utils.generateRandomHex64(),
        'created_at': 1234567890,
        'kind': 1222,
        'content': '',
        'tags': [],
        'sig': '',
      });

      // Test setters
      partialVoiceMessage.description = 'Updated description';
      partialVoiceMessage.audioUrl = 'https://new.example.com/voice.mp3';
      partialVoiceMessage.duration = 90;
      partialVoiceMessage.transcript = 'Updated transcript';
      partialVoiceMessage.hashtags = {'updated', 'test'};

      // Test add/remove methods
      partialVoiceMessage.addHashtag('new');
      partialVoiceMessage.addAudioUrl('https://alt.example.com/voice.ogg');

      expect(partialVoiceMessage.description, 'Updated description');
      expect(partialVoiceMessage.audioUrl, 'https://new.example.com/voice.mp3');
      expect(partialVoiceMessage.duration, 90);
      expect(partialVoiceMessage.transcript, 'Updated transcript');
      expect(partialVoiceMessage.hashtags, {'updated', 'test', 'new'});
      expect(partialVoiceMessage.allAudioUrls, {
        'https://new.example.com/voice.mp3',
        'https://alt.example.com/voice.ogg',
      });
    });
  });

  group('VoiceMessageComment', () {
    test('creates a valid voice message comment event', () async {
      final originalVoiceMessage = VoiceMessage.fromMap({
        'id': Utils.generateRandomHex64(),
        'pubkey': Utils.generateRandomHex64(),
        'created_at': 1234567890,
        'kind': 1222,
        'content': 'Original voice message',
        'tags': [
          ['url', 'https://example.com/original.mp3'],
        ],
        'sig': 'signature',
      }, ref);

      final voiceComment = PartialVoiceMessageComment(
        audioUrl: 'https://example.com/comment.mp3',
        originalVoiceMessage: originalVoiceMessage,
        description: 'Voice response',
        duration: 30,
        transcript: 'Thanks for your message',
        altText: 'Voice response thanking for message',
        hashtags: {'response', 'thanks'},
        location: 'Boston',
        mimeType: 'audio/mp3',
        fileSize: 256000,
        audioHash: 'def456',
        waveform: 'comment_waveform',
      ).dummySign(nielPubkey);

      expect(voiceComment.event.kind, 1244);
      expect(
        voiceComment.description,
        'https://example.com/comment.mp3',
      ); // Per NIP-A0: content contains audio URL
      expect(voiceComment.audioUrl, 'https://example.com/comment.mp3');
      expect(voiceComment.duration, 30);
      expect(voiceComment.transcript, 'Thanks for your message');
      expect(voiceComment.altText, 'Voice response thanking for message');
      expect(voiceComment.hashtags, {'response', 'thanks'});
      expect(voiceComment.location, 'Boston');
      expect(voiceComment.mimeType, 'audio/mp3');
      expect(voiceComment.fileSize, 256000);
      expect(voiceComment.audioHash, 'def456');
      expect(voiceComment.waveform, 'comment_waveform');
      expect(voiceComment.formattedDuration, '0:30');

      // Check that original voice message reference is set
      expect(voiceComment.event.containsTag('e'), true);
      expect(
        voiceComment.event.getFirstTagValue('e'),
        originalVoiceMessage.event.id,
      );
    });

    test('creates minimal voice comment without original message', () async {
      final voiceComment = PartialVoiceMessageComment(
        audioUrl: 'https://example.com/comment.wav',
      ).dummySign(nielPubkey);

      expect(voiceComment.event.kind, 1244);
      expect(voiceComment.audioUrl, 'https://example.com/comment.wav');
      expect(
        voiceComment.description,
        'https://example.com/comment.wav',
      ); // Per NIP-A0: content contains audio URL
      expect(voiceComment.event.containsTag('e'), false);
    });

    test('parses voice comment from event map', () {
      final originalVoiceMessageId = Utils.generateRandomHex64();
      final eventMap = {
        'id': Utils.generateRandomHex64(),
        'pubkey': Utils.generateRandomHex64(),
        'created_at': 1234567890,
        'kind': 1244,
        'content':
            'https://example.com/comment.mp3', // Per NIP-A0: content must be audio URL
        'tags': [
          ['e', originalVoiceMessageId],
          ['x', 'commenthash123'],
          ['m', 'audio/mp3'],
          ['size', '128000'],
          ['duration', '25'],
          ['transcript', 'Great message!'],
          ['alt', 'Voice saying great message'],
          ['t', 'feedback'],
          ['location', 'Chicago'],
          ['g', 'commentgeohash'],
        ],
        'sig': 'signature',
      };

      final voiceComment = VoiceMessageComment.fromMap(eventMap, ref);

      expect(
        voiceComment.description,
        'https://example.com/comment.mp3',
      ); // Per NIP-A0: description returns content (audio URL)
      expect(voiceComment.audioUrl, 'https://example.com/comment.mp3');
      expect(voiceComment.audioHash, 'commenthash123');
      expect(voiceComment.mimeType, 'audio/mp3');
      expect(voiceComment.fileSize, 128000);
      expect(voiceComment.duration, 25);
      expect(voiceComment.transcript, 'Great message!');
      expect(voiceComment.altText, 'Voice saying great message');
      expect(voiceComment.hashtags, {'feedback'});
      expect(voiceComment.location, 'Chicago');
      expect(voiceComment.geohash, 'commentgeohash');
      expect(voiceComment.formattedDuration, '0:25');

      // Test original voice message relationship
      expect(voiceComment.originalVoiceMessage, isA<BelongsTo<VoiceMessage>>());
    });

    test('handles partial voice comment modification', () {
      final partialVoiceComment = PartialVoiceMessageComment.fromMap({
        'id': Utils.generateRandomHex64(),
        'pubkey': Utils.generateRandomHex64(),
        'created_at': 1234567890,
        'kind': 1244,
        'content': '',
        'tags': [],
        'sig': '',
      });

      // Test setters
      partialVoiceComment.description = 'Updated comment';
      partialVoiceComment.audioUrl = 'https://new.example.com/comment.mp3';
      partialVoiceComment.duration = 60;
      partialVoiceComment.transcript = 'Updated comment transcript';

      expect(partialVoiceComment.description, 'Updated comment');
      expect(
        partialVoiceComment.audioUrl,
        'https://new.example.com/comment.mp3',
      );
      expect(partialVoiceComment.duration, 60);
      expect(partialVoiceComment.transcript, 'Updated comment transcript');
    });
  });

  group('Voice Message Relationships', () {
    test('voice message has relationships with notes and comments', () {
      final voiceMessage = VoiceMessage.fromMap({
        'id': Utils.generateRandomHex64(),
        'pubkey': Utils.generateRandomHex64(),
        'created_at': 1234567890,
        'kind': 1222,
        'content': 'Test voice message',
        'tags': [
          ['url', 'https://example.com/voice.mp3'],
        ],
        'sig': 'signature',
      }, ref);

      expect(voiceMessage.referencingNotes, isA<HasMany<Note>>());
      expect(voiceMessage.comments, isA<HasMany<Comment>>());
      expect(voiceMessage.voiceComments, isA<HasMany<VoiceMessageComment>>());
    });

    test('voice comment has relationship with original voice message', () {
      final originalId = Utils.generateRandomHex64();
      final voiceComment = VoiceMessageComment.fromMap({
        'id': Utils.generateRandomHex64(),
        'pubkey': Utils.generateRandomHex64(),
        'created_at': 1234567890,
        'kind': 1244,
        'content': 'Test voice comment',
        'tags': [
          ['e', originalId],
          ['url', 'https://example.com/comment.mp3'],
        ],
        'sig': 'signature',
      }, ref);

      expect(voiceComment.originalVoiceMessage, isA<BelongsTo<VoiceMessage>>());
      expect(voiceComment.referencingNotes, isA<HasMany<Note>>());
      expect(voiceComment.comments, isA<HasMany<Comment>>());
    });
  });

  group('Voice Message Duration Formatting', () {
    test('formats durations correctly', () {
      final testCases = [
        (0, '0:00'),
        (5, '0:05'),
        (30, '0:30'),
        (60, '1:00'),
        (65, '1:05'),
        (90, '1:30'),
        (120, '2:00'),
        (3661, '61:01'), // Over an hour
      ];

      for (final (seconds, expected) in testCases) {
        final voiceMessage = VoiceMessage.fromMap({
          'id': Utils.generateRandomHex64(),
          'pubkey': Utils.generateRandomHex64(),
          'created_at': 1234567890,
          'kind': 1222,
          'content': 'Test',
          'tags': [
            ['url', 'https://example.com/voice.mp3'],
            ['duration', seconds.toString()],
          ],
          'sig': 'signature',
        }, ref);

        expect(
          voiceMessage.formattedDuration,
          expected,
          reason: 'Failed for $seconds seconds',
        );
      }
    });

    test('returns null for missing duration', () {
      final voiceMessage = VoiceMessage.fromMap({
        'id': Utils.generateRandomHex64(),
        'pubkey': Utils.generateRandomHex64(),
        'created_at': 1234567890,
        'kind': 1222,
        'content': 'Test',
        'tags': [
          ['url', 'https://example.com/voice.mp3'],
        ],
        'sig': 'signature',
      }, ref);

      expect(voiceMessage.formattedDuration, null);
    });
  });
}

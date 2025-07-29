part of models;

/// A voice message event (kind 1222) for sharing audio messages on Nostr.
///
/// Voice messages enable users to share audio recordings as an alternative
/// to text-based communication. They include the audio URL, duration,
/// and optional metadata like transcript and waveform data.
class VoiceMessage extends RegularModel<VoiceMessage> {
  /// Notes that reference this voice message
  late final HasMany<Note> referencingNotes;

  /// Comments on this voice message
  late final HasMany<Comment> comments;

  /// Voice message comments (kind 1244) on this voice message
  late final HasMany<VoiceMessageComment> voiceComments;

  VoiceMessage.fromMap(super.map, super.ref) : super.fromMap() {
    referencingNotes = HasMany(
      ref,
      RequestFilter<Note>(
        tags: {
          '#e': {event.id},
        },
      ).toRequest(),
    );

    comments = HasMany(
      ref,
      RequestFilter<Comment>(
        tags: {
          '#E': {event.id},
        },
      ).toRequest(),
    );

    voiceComments = HasMany(
      ref,
      RequestFilter<VoiceMessageComment>(
        tags: {
          '#e': {event.id},
        },
      ).toRequest(),
    );
  }

  /// The voice message description or caption
  String get description => event.content;

  /// The primary audio file URL
  String? get audioUrl => event.getFirstTagValue('url');

  /// Alternative audio URLs for different qualities or formats
  Set<String> get altAudioUrls => event.getTagSetValues('url').skip(1).toSet();

  /// All audio URLs (primary + alternatives)
  Set<String> get allAudioUrls => event.getTagSetValues('url');

  /// The audio file hash for verification
  String? get audioHash => event.getFirstTagValue('x');

  /// Audio MIME type (e.g., 'audio/mp3', 'audio/wav', 'audio/ogg')
  String? get mimeType => event.getFirstTagValue('m');

  /// File size in bytes
  int? get fileSize {
    final sizeStr = event.getFirstTagValue('size');
    return sizeStr != null ? int.tryParse(sizeStr) : null;
  }

  /// Audio duration in seconds
  int? get duration {
    final durationStr = event.getFirstTagValue('duration');
    return durationStr != null ? int.tryParse(durationStr) : null;
  }

  /// Audio waveform data (optional, for visual representation)
  String? get waveform => event.getFirstTagValue('waveform');

  /// Text transcript of the voice message (optional)
  String? get transcript => event.getFirstTagValue('transcript');

  /// Alternative text for accessibility
  String? get altText => event.getFirstTagValue('alt');

  /// Hashtags associated with this voice message
  Set<String> get hashtags => event.getTagSetValues('t');

  /// Location where the voice message was recorded
  String? get location => event.getFirstTagValue('location');

  /// Geohash for location-based queries
  String? get geohash => event.getFirstTagValue('g');

  /// Voice message title
  String? get title => event.getFirstTagValue('title');

  /// Summary or brief description
  String? get summary => event.getFirstTagValue('summary');

  /// Whether this voice message has location information
  bool get hasLocation => location != null || geohash != null;

  /// Whether this voice message has accessibility text
  bool get hasAltText => altText != null && altText!.isNotEmpty;

  /// Whether this voice message has a transcript
  bool get hasTranscript => transcript != null && transcript!.isNotEmpty;

  /// Whether this voice message has waveform data
  bool get hasWaveform => waveform != null && waveform!.isNotEmpty;

  /// Get duration in a human-readable format (e.g., "1:23")
  String? get formattedDuration {
    final dur = duration;
    if (dur == null) return null;

    final minutes = dur ~/ 60;
    final seconds = dur % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// A voice message comment event (kind 1244) for commenting on voice messages.
///
/// Voice message comments are audio responses to voice messages, enabling
/// voice-based conversations and discussions.
class VoiceMessageComment extends RegularModel<VoiceMessageComment> {
  /// The original voice message being commented on
  late final BelongsTo<VoiceMessage> originalVoiceMessage;

  /// Notes that reference this voice message comment
  late final HasMany<Note> referencingNotes;

  /// Comments on this voice message comment
  late final HasMany<Comment> comments;

  VoiceMessageComment.fromMap(super.map, super.ref) : super.fromMap() {
    originalVoiceMessage = BelongsTo(
      ref,
      event.containsTag('e')
          ? Request<VoiceMessage>.fromIds({event.getFirstTagValue('e')!})
          : null,
    );

    referencingNotes = HasMany(
      ref,
      RequestFilter<Note>(
        tags: {
          '#e': {event.id},
        },
      ).toRequest(),
    );

    comments = HasMany(
      ref,
      RequestFilter<Comment>(
        tags: {
          '#E': {event.id},
        },
      ).toRequest(),
    );
  }

  /// The voice comment description or caption
  String get description => event.content;

  /// The primary audio file URL
  String? get audioUrl => event.getFirstTagValue('url');

  /// Alternative audio URLs for different qualities or formats
  Set<String> get altAudioUrls => event.getTagSetValues('url').skip(1).toSet();

  /// All audio URLs (primary + alternatives)
  Set<String> get allAudioUrls => event.getTagSetValues('url');

  /// The audio file hash for verification
  String? get audioHash => event.getFirstTagValue('x');

  /// Audio MIME type (e.g., 'audio/mp3', 'audio/wav', 'audio/ogg')
  String? get mimeType => event.getFirstTagValue('m');

  /// File size in bytes
  int? get fileSize {
    final sizeStr = event.getFirstTagValue('size');
    return sizeStr != null ? int.tryParse(sizeStr) : null;
  }

  /// Audio duration in seconds
  int? get duration {
    final durationStr = event.getFirstTagValue('duration');
    return durationStr != null ? int.tryParse(durationStr) : null;
  }

  /// Audio waveform data (optional, for visual representation)
  String? get waveform => event.getFirstTagValue('waveform');

  /// Text transcript of the voice comment (optional)
  String? get transcript => event.getFirstTagValue('transcript');

  /// Alternative text for accessibility
  String? get altText => event.getFirstTagValue('alt');

  /// Hashtags associated with this voice comment
  Set<String> get hashtags => event.getTagSetValues('t');

  /// Location where the voice comment was recorded
  String? get location => event.getFirstTagValue('location');

  /// Geohash for location-based queries
  String? get geohash => event.getFirstTagValue('g');

  /// Whether this voice comment has location information
  bool get hasLocation => location != null || geohash != null;

  /// Whether this voice comment has accessibility text
  bool get hasAltText => altText != null && altText!.isNotEmpty;

  /// Whether this voice comment has a transcript
  bool get hasTranscript => transcript != null && transcript!.isNotEmpty;

  /// Whether this voice comment has waveform data
  bool get hasWaveform => waveform != null && waveform!.isNotEmpty;

  /// Get duration in a human-readable format (e.g., "1:23")
  String? get formattedDuration {
    final dur = duration;
    if (dur == null) return null;

    final minutes = dur ~/ 60;
    final seconds = dur % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Generated partial model mixin for VoiceMessage
mixin PartialVoiceMessageMixin on RegularPartialModel<VoiceMessage> {
  /// The voice message description or caption
  String? get description => event.content.isEmpty ? null : event.content;

  /// Sets the voice message description or caption
  set description(String? value) => event.content = value ?? '';

  /// The primary audio file URL
  String? get audioUrl => event.getFirstTagValue('url');

  /// Sets the primary audio file URL
  set audioUrl(String? value) => event.setTagValue('url', value);

  /// All audio URLs (primary + alternatives)
  Set<String> get allAudioUrls => event.getTagSetValues('url');

  /// Sets all audio URLs
  set allAudioUrls(Set<String> value) => event.setTagValues('url', value);

  /// Adds an audio URL
  void addAudioUrl(String? value) => event.addTagValue('url', value);

  /// Removes an audio URL
  void removeAudioUrl(String? value) => event.removeTagWithValue('url', value);

  /// The audio file hash for verification
  String? get audioHash => event.getFirstTagValue('x');

  /// Sets the audio file hash
  set audioHash(String? value) => event.setTagValue('x', value);

  /// Audio MIME type
  String? get mimeType => event.getFirstTagValue('m');

  /// Sets the audio MIME type
  set mimeType(String? value) => event.setTagValue('m', value);

  /// File size in bytes
  int? get fileSize {
    final sizeStr = event.getFirstTagValue('size');
    return sizeStr != null ? int.tryParse(sizeStr) : null;
  }

  /// Sets the file size in bytes
  set fileSize(int? value) => event.setTagValue('size', value?.toString());

  /// Audio duration in seconds
  int? get duration {
    final durationStr = event.getFirstTagValue('duration');
    return durationStr != null ? int.tryParse(durationStr) : null;
  }

  /// Sets the audio duration in seconds
  set duration(int? value) => event.setTagValue('duration', value?.toString());

  /// Audio waveform data
  String? get waveform => event.getFirstTagValue('waveform');

  /// Sets the audio waveform data
  set waveform(String? value) => event.setTagValue('waveform', value);

  /// Text transcript of the voice message
  String? get transcript => event.getFirstTagValue('transcript');

  /// Sets the text transcript
  set transcript(String? value) => event.setTagValue('transcript', value);

  /// Alternative text for accessibility
  String? get altText => event.getFirstTagValue('alt');

  /// Sets the alternative text for accessibility
  set altText(String? value) => event.setTagValue('alt', value);

  /// Hashtags associated with this voice message
  Set<String> get hashtags => event.getTagSetValues('t');

  /// Sets the hashtags associated with this voice message
  set hashtags(Set<String> value) => event.setTagValues('t', value);

  /// Adds a hashtag
  void addHashtag(String? value) => event.addTagValue('t', value);

  /// Removes a hashtag
  void removeHashtag(String? value) => event.removeTagWithValue('t', value);

  /// Location where the voice message was recorded
  String? get location => event.getFirstTagValue('location');

  /// Sets the location where the voice message was recorded
  set location(String? value) => event.setTagValue('location', value);

  /// Geohash for location-based queries
  String? get geohash => event.getFirstTagValue('g');

  /// Sets the geohash for location-based queries
  set geohash(String? value) => event.setTagValue('g', value);

  /// Voice message title
  String? get title => event.getFirstTagValue('title');

  /// Sets the voice message title
  set title(String? value) => event.setTagValue('title', value);

  /// Summary or brief description
  String? get summary => event.getFirstTagValue('summary');

  /// Sets the summary or brief description
  set summary(String? value) => event.setTagValue('summary', value);
}

/// Generated partial model mixin for VoiceMessageComment
mixin PartialVoiceMessageCommentMixin
    on RegularPartialModel<VoiceMessageComment> {
  /// The voice comment description or caption
  String? get description => event.content.isEmpty ? null : event.content;

  /// Sets the voice comment description or caption
  set description(String? value) => event.content = value ?? '';

  /// The primary audio file URL
  String? get audioUrl => event.getFirstTagValue('url');

  /// Sets the primary audio file URL
  set audioUrl(String? value) => event.setTagValue('url', value);

  /// All audio URLs (primary + alternatives)
  Set<String> get allAudioUrls => event.getTagSetValues('url');

  /// Sets all audio URLs
  set allAudioUrls(Set<String> value) => event.setTagValues('url', value);

  /// Adds an audio URL
  void addAudioUrl(String? value) => event.addTagValue('url', value);

  /// Removes an audio URL
  void removeAudioUrl(String? value) => event.removeTagWithValue('url', value);

  /// The audio file hash for verification
  String? get audioHash => event.getFirstTagValue('x');

  /// Sets the audio file hash
  set audioHash(String? value) => event.setTagValue('x', value);

  /// Audio MIME type
  String? get mimeType => event.getFirstTagValue('m');

  /// Sets the audio MIME type
  set mimeType(String? value) => event.setTagValue('m', value);

  /// File size in bytes
  int? get fileSize {
    final sizeStr = event.getFirstTagValue('size');
    return sizeStr != null ? int.tryParse(sizeStr) : null;
  }

  /// Sets the file size in bytes
  set fileSize(int? value) => event.setTagValue('size', value?.toString());

  /// Audio duration in seconds
  int? get duration {
    final durationStr = event.getFirstTagValue('duration');
    return durationStr != null ? int.tryParse(durationStr) : null;
  }

  /// Sets the audio duration in seconds
  set duration(int? value) => event.setTagValue('duration', value?.toString());

  /// Audio waveform data
  String? get waveform => event.getFirstTagValue('waveform');

  /// Sets the audio waveform data
  set waveform(String? value) => event.setTagValue('waveform', value);

  /// Text transcript of the voice comment
  String? get transcript => event.getFirstTagValue('transcript');

  /// Sets the text transcript
  set transcript(String? value) => event.setTagValue('transcript', value);

  /// Alternative text for accessibility
  String? get altText => event.getFirstTagValue('alt');

  /// Sets the alternative text for accessibility
  set altText(String? value) => event.setTagValue('alt', value);

  /// Hashtags associated with this voice comment
  Set<String> get hashtags => event.getTagSetValues('t');

  /// Sets the hashtags associated with this voice comment
  set hashtags(Set<String> value) => event.setTagValues('t', value);

  /// Adds a hashtag
  void addHashtag(String? value) => event.addTagValue('t', value);

  /// Removes a hashtag
  void removeHashtag(String? value) => event.removeTagWithValue('t', value);

  /// Location where the voice comment was recorded
  String? get location => event.getFirstTagValue('location');

  /// Sets the location where the voice comment was recorded
  set location(String? value) => event.setTagValue('location', value);

  /// Geohash for location-based queries
  String? get geohash => event.getFirstTagValue('g');

  /// Sets the geohash for location-based queries
  set geohash(String? value) => event.setTagValue('g', value);
}

/// Create and sign new voice message events.
///
/// Example usage:
/// ```dart
/// final voiceMessage = await PartialVoiceMessage(
///   audioUrl: 'https://example.com/voice.mp3',
///   description: 'Quick voice note about the meeting',
///   duration: 45,
///   transcript: 'Hey everyone, just a quick update...',
/// ).signWith(signer);
/// ```
class PartialVoiceMessage extends RegularPartialModel<VoiceMessage>
    with PartialVoiceMessageMixin {
  PartialVoiceMessage.fromMap(super.map) : super.fromMap();

  /// Creates a new voice message event
  ///
  /// [audioUrl] - The primary audio file URL (required)
  /// [description] - Voice message description or caption (optional)
  /// [duration] - Audio duration in seconds (optional)
  /// [transcript] - Text transcript of the audio (optional)
  /// [title] - Voice message title (optional)
  /// [altText] - Alternative text for accessibility (optional)
  /// [hashtags] - Set of hashtags (optional)
  /// [location] - Location where recorded (optional)
  /// [mimeType] - Audio MIME type (optional)
  /// [fileSize] - File size in bytes (optional)
  /// [audioHash] - File hash for verification (optional)
  /// [waveform] - Waveform data for visualization (optional)
  /// [summary] - Brief description or summary (optional)
  PartialVoiceMessage({
    required String audioUrl,
    String? description,
    int? duration,
    String? transcript,
    String? title,
    String? altText,
    Set<String>? hashtags,
    String? location,
    String? mimeType,
    int? fileSize,
    String? audioHash,
    String? waveform,
    String? summary,
  }) {
    this.audioUrl = audioUrl;
    if (description != null) this.description = description;
    if (duration != null) this.duration = duration;
    if (transcript != null) this.transcript = transcript;
    if (title != null) this.title = title;
    if (altText != null) this.altText = altText;
    if (hashtags != null) this.hashtags = hashtags;
    if (location != null) this.location = location;
    if (mimeType != null) this.mimeType = mimeType;
    if (fileSize != null) this.fileSize = fileSize;
    if (audioHash != null) this.audioHash = audioHash;
    if (waveform != null) this.waveform = waveform;
    if (summary != null) this.summary = summary;
  }
}

/// Create and sign new voice message comment events.
///
/// Example usage:
/// ```dart
/// final voiceComment = await PartialVoiceMessageComment(
///   audioUrl: 'https://example.com/comment.mp3',
///   originalVoiceMessage: originalMessage,
///   description: 'Voice response to your message',
///   duration: 30,
/// ).signWith(signer);
/// ```
class PartialVoiceMessageComment
    extends RegularPartialModel<VoiceMessageComment>
    with PartialVoiceMessageCommentMixin {
  PartialVoiceMessageComment.fromMap(super.map) : super.fromMap();

  /// Creates a new voice message comment event
  ///
  /// [audioUrl] - The primary audio file URL (required)
  /// [originalVoiceMessage] - The voice message being commented on (optional)
  /// [description] - Voice comment description or caption (optional)
  /// [duration] - Audio duration in seconds (optional)
  /// [transcript] - Text transcript of the audio (optional)
  /// [altText] - Alternative text for accessibility (optional)
  /// [hashtags] - Set of hashtags (optional)
  /// [location] - Location where recorded (optional)
  /// [mimeType] - Audio MIME type (optional)
  /// [fileSize] - File size in bytes (optional)
  /// [audioHash] - File hash for verification (optional)
  /// [waveform] - Waveform data for visualization (optional)
  PartialVoiceMessageComment({
    required String audioUrl,
    VoiceMessage? originalVoiceMessage,
    String? description,
    int? duration,
    String? transcript,
    String? altText,
    Set<String>? hashtags,
    String? location,
    String? mimeType,
    int? fileSize,
    String? audioHash,
    String? waveform,
  }) {
    this.audioUrl = audioUrl;
    if (originalVoiceMessage != null) {
      event.tags.add(['e', originalVoiceMessage.event.id]);
    }
    if (description != null) this.description = description;
    if (duration != null) this.duration = duration;
    if (transcript != null) this.transcript = transcript;
    if (altText != null) this.altText = altText;
    if (hashtags != null) this.hashtags = hashtags;
    if (location != null) this.location = location;
    if (mimeType != null) this.mimeType = mimeType;
    if (fileSize != null) this.fileSize = fileSize;
    if (audioHash != null) this.audioHash = audioHash;
    if (waveform != null) this.waveform = waveform;
  }
}

part of models;

/// A video event (kind 21) for sharing videos on Nostr.
///
/// Video events are designed for video-centric social media experiences,
/// similar to YouTube or TikTok posts. They include the video URL, description,
/// thumbnail, and optional metadata about the video.
class Video extends RegularModel<Video> {
  /// Notes that reference this video
  late final HasMany<Note> referencingNotes;

  /// Comments on this video
  late final HasMany<Comment> comments;

  Video.fromMap(super.map, super.ref) : super.fromMap() {
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

  /// The video description or caption
  String get description => event.content;

  /// The primary video URL
  String? get videoUrl {
    // First try to get URL from imeta tags (NIP-71)
    final imetaUrls = Utils.extractImetaUrls(event.getTagSet('imeta'));
    if (imetaUrls.isNotEmpty) return imetaUrls.first;

    // Fall back to simple url tags
    return event.getFirstTagValue('url');
  }

  /// Alternative video URLs for different qualities or formats
  Set<String> get altVideoUrls => event.getTagSetValues('url').skip(1).toSet();

  /// All video URLs (primary + alternatives)
  Set<String> get allVideoUrls {
    final urls = <String>{};

    // Add URLs from imeta tags (NIP-71)
    urls.addAll(Utils.extractImetaUrls(event.getTagSet('imeta')));

    // Add URLs from simple url tags
    urls.addAll(event.getTagSetValues('url'));

    return urls;
  }

  /// The video file hash for verification
  String? get videoHash => event.getFirstTagValue('x');

  /// Video dimensions in format "widthxheight"
  String? get dimensions => event.getFirstTagValue('dim');

  /// Video width in pixels
  int? get width {
    final dim = dimensions;
    if (dim == null) return null;
    final parts = dim.split('x');
    return parts.isNotEmpty ? int.tryParse(parts[0]) : null;
  }

  /// Video height in pixels
  int? get height {
    final dim = dimensions;
    if (dim == null) return null;
    final parts = dim.split('x');
    return parts.length > 1 ? int.tryParse(parts[1]) : null;
  }

  /// Video MIME type (e.g., 'video/mp4', 'video/webm')
  String? get mimeType => event.getFirstTagValue('m');

  /// File size in bytes
  int? get fileSize {
    final sizeStr = event.getFirstTagValue('size');
    return sizeStr != null ? int.tryParse(sizeStr) : null;
  }

  /// Video duration in seconds
  int? get duration {
    final durationStr = event.getFirstTagValue('duration');
    return durationStr != null ? int.tryParse(durationStr) : null;
  }

  /// Thumbnail image URL
  String? get thumbnailUrl => event.getFirstTagValue('thumb');

  /// Alternative text for accessibility
  String? get altText => event.getFirstTagValue('alt');

  /// Hashtags associated with this video
  Set<String> get hashtags => event.getTagSetValues('t');

  /// Location where the video was recorded
  String? get location => event.getFirstTagValue('location');

  /// Geohash for location-based queries
  String? get geohash => event.getFirstTagValue('g');

  /// Video title
  String? get title => event.getFirstTagValue('title');

  /// Summary or brief description
  String? get summary => event.getFirstTagValue('summary');

  /// Whether this video has location information
  bool get hasLocation => location != null || geohash != null;

  /// Whether this video has accessibility text
  bool get hasAltText => altText != null && altText!.isNotEmpty;

  /// Whether this video has a thumbnail
  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
}

/// A short-form portrait video event (kind 22) for vertical video content.
///
/// Short-form portrait videos are designed for mobile-first vertical video
/// experiences, similar to TikTok, Instagram Reels, or YouTube Shorts.
/// They extend the base Video model with additional portrait-specific features.
class ShortFormPortraitVideo extends RegularModel<ShortFormPortraitVideo> {
  /// Notes that reference this video
  late final HasMany<Note> referencingNotes;

  /// Comments on this video
  late final HasMany<Comment> comments;

  ShortFormPortraitVideo.fromMap(super.map, super.ref) : super.fromMap() {
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

  /// The video description or caption
  String get description => event.content;

  /// The primary video URL
  String? get videoUrl {
    // First try to get URL from imeta tags (NIP-71)
    final imetaUrls = Utils.extractImetaUrls(event.getTagSet('imeta'));
    if (imetaUrls.isNotEmpty) return imetaUrls.first;

    // Fall back to simple url tags
    return event.getFirstTagValue('url');
  }

  /// Alternative video URLs for different qualities or formats
  Set<String> get altVideoUrls => event.getTagSetValues('url').skip(1).toSet();

  /// All video URLs (primary + alternatives)
  Set<String> get allVideoUrls {
    final urls = <String>{};

    // Add URLs from imeta tags (NIP-71)
    urls.addAll(Utils.extractImetaUrls(event.getTagSet('imeta')));

    // Add URLs from simple url tags
    urls.addAll(event.getTagSetValues('url'));

    return urls;
  }

  /// The video file hash for verification
  String? get videoHash => event.getFirstTagValue('x');

  /// Video dimensions in format "widthxheight" (should be portrait orientation)
  String? get dimensions => event.getFirstTagValue('dim');

  /// Video width in pixels
  int? get width {
    final dim = dimensions;
    if (dim == null) return null;
    final parts = dim.split('x');
    return parts.isNotEmpty ? int.tryParse(parts[0]) : null;
  }

  /// Video height in pixels
  int? get height {
    final dim = dimensions;
    if (dim == null) return null;
    final parts = dim.split('x');
    return parts.length > 1 ? int.tryParse(parts[1]) : null;
  }

  /// Whether this video is in portrait orientation (height > width)
  bool get isPortrait {
    final w = width;
    final h = height;
    if (w == null || h == null) return false;
    return h > w;
  }

  /// Video MIME type (e.g., 'video/mp4', 'video/webm')
  String? get mimeType => event.getFirstTagValue('m');

  /// File size in bytes
  int? get fileSize {
    final sizeStr = event.getFirstTagValue('size');
    return sizeStr != null ? int.tryParse(sizeStr) : null;
  }

  /// Video duration in seconds (typically short for this format)
  int? get duration {
    final durationStr = event.getFirstTagValue('duration');
    return durationStr != null ? int.tryParse(durationStr) : null;
  }

  /// Thumbnail image URL
  String? get thumbnailUrl => event.getFirstTagValue('thumb');

  /// Alternative text for accessibility
  String? get altText => event.getFirstTagValue('alt');

  /// Hashtags associated with this video
  Set<String> get hashtags => event.getTagSetValues('t');

  /// Location where the video was recorded
  String? get location => event.getFirstTagValue('location');

  /// Geohash for location-based queries
  String? get geohash => event.getFirstTagValue('g');

  /// Video title
  String? get title => event.getFirstTagValue('title');

  /// Summary or brief description
  String? get summary => event.getFirstTagValue('summary');

  /// Whether this video has location information
  bool get hasLocation => location != null || geohash != null;

  /// Whether this video has accessibility text
  bool get hasAltText => altText != null && altText!.isNotEmpty;

  /// Whether this video has a thumbnail
  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
}

/// Generated partial model mixin for Video
mixin PartialVideoMixin on RegularPartialModel<Video> {
  /// The video description or caption
  String? get description => event.content.isEmpty ? null : event.content;

  /// Sets the video description or caption
  set description(String? value) => event.content = value ?? '';

  /// The primary video URL
  String? get videoUrl {
    // First try to get URL from imeta tags (NIP-71)
    final imetaUrls = Utils.extractImetaUrls(event.getTagSet('imeta'));
    if (imetaUrls.isNotEmpty) return imetaUrls.first;

    // Fall back to simple url tags
    return event.getFirstTagValue('url');
  }

  /// Sets the primary video URL
  set videoUrl(String? value) => event.setTagValue('url', value);

  /// All video URLs (primary + alternatives)
  Set<String> get allVideoUrls {
    final urls = <String>{};

    // Add URLs from imeta tags (NIP-71)
    urls.addAll(Utils.extractImetaUrls(event.getTagSet('imeta')));

    // Add URLs from simple url tags
    urls.addAll(event.getTagSetValues('url'));

    return urls;
  }

  /// Sets all video URLs
  set allVideoUrls(Set<String> value) => event.setTagValues('url', value);

  /// Adds a video URL
  void addVideoUrl(String? value) => event.addTagValue('url', value);

  /// Removes a video URL
  void removeVideoUrl(String? value) => event.removeTagWithValue('url', value);

  /// The video file hash for verification
  String? get videoHash => event.getFirstTagValue('x');

  /// Sets the video file hash
  set videoHash(String? value) => event.setTagValue('x', value);

  /// Video dimensions in format "widthxheight"
  String? get dimensions => event.getFirstTagValue('dim');

  /// Sets the video dimensions
  set dimensions(String? value) => event.setTagValue('dim', value);

  /// Video MIME type
  String? get mimeType => event.getFirstTagValue('m');

  /// Sets the video MIME type
  set mimeType(String? value) => event.setTagValue('m', value);

  /// File size in bytes
  int? get fileSize {
    final sizeStr = event.getFirstTagValue('size');
    return sizeStr != null ? int.tryParse(sizeStr) : null;
  }

  /// Sets the file size in bytes
  set fileSize(int? value) => event.setTagValue('size', value?.toString());

  /// Video duration in seconds
  int? get duration {
    final durationStr = event.getFirstTagValue('duration');
    return durationStr != null ? int.tryParse(durationStr) : null;
  }

  /// Sets the video duration in seconds
  set duration(int? value) => event.setTagValue('duration', value?.toString());

  /// Thumbnail image URL
  String? get thumbnailUrl => event.getFirstTagValue('thumb');

  /// Sets the thumbnail image URL
  set thumbnailUrl(String? value) => event.setTagValue('thumb', value);

  /// Alternative text for accessibility
  String? get altText => event.getFirstTagValue('alt');

  /// Sets the alternative text for accessibility
  set altText(String? value) => event.setTagValue('alt', value);

  /// Hashtags associated with this video
  Set<String> get hashtags => event.getTagSetValues('t');

  /// Sets the hashtags associated with this video
  set hashtags(Set<String> value) => event.setTagValues('t', value);

  /// Adds a hashtag
  void addHashtag(String? value) => event.addTagValue('t', value);

  /// Removes a hashtag
  void removeHashtag(String? value) => event.removeTagWithValue('t', value);

  /// Location where the video was recorded
  String? get location => event.getFirstTagValue('location');

  /// Sets the location where the video was recorded
  set location(String? value) => event.setTagValue('location', value);

  /// Geohash for location-based queries
  String? get geohash => event.getFirstTagValue('g');

  /// Sets the geohash for location-based queries
  set geohash(String? value) => event.setTagValue('g', value);

  /// Video title
  String? get title => event.getFirstTagValue('title');

  /// Sets the video title
  set title(String? value) => event.setTagValue('title', value);

  /// Summary or brief description
  String? get summary => event.getFirstTagValue('summary');

  /// Sets the summary or brief description
  set summary(String? value) => event.setTagValue('summary', value);
}

/// Generated partial model mixin for ShortFormPortraitVideo
mixin PartialShortFormPortraitVideoMixin
    on RegularPartialModel<ShortFormPortraitVideo> {
  /// The video description or caption
  String? get description => event.content.isEmpty ? null : event.content;

  /// Sets the video description or caption
  set description(String? value) => event.content = value ?? '';

  /// The primary video URL
  String? get videoUrl {
    // First try to get URL from imeta tags (NIP-71)
    final imetaUrls = Utils.extractImetaUrls(event.getTagSet('imeta'));
    if (imetaUrls.isNotEmpty) return imetaUrls.first;

    // Fall back to simple url tags
    return event.getFirstTagValue('url');
  }

  /// Sets the primary video URL
  set videoUrl(String? value) => event.setTagValue('url', value);

  /// All video URLs (primary + alternatives)
  Set<String> get allVideoUrls {
    final urls = <String>{};

    // Add URLs from imeta tags (NIP-71)
    urls.addAll(Utils.extractImetaUrls(event.getTagSet('imeta')));

    // Add URLs from simple url tags
    urls.addAll(event.getTagSetValues('url'));

    return urls;
  }

  /// Sets all video URLs
  set allVideoUrls(Set<String> value) => event.setTagValues('url', value);

  /// Adds a video URL
  void addVideoUrl(String? value) => event.addTagValue('url', value);

  /// Removes a video URL
  void removeVideoUrl(String? value) => event.removeTagWithValue('url', value);

  /// The video file hash for verification
  String? get videoHash => event.getFirstTagValue('x');

  /// Sets the video file hash
  set videoHash(String? value) => event.setTagValue('x', value);

  /// Video dimensions in format "widthxheight"
  String? get dimensions => event.getFirstTagValue('dim');

  /// Sets the video dimensions
  set dimensions(String? value) => event.setTagValue('dim', value);

  /// Video MIME type
  String? get mimeType => event.getFirstTagValue('m');

  /// Sets the video MIME type
  set mimeType(String? value) => event.setTagValue('m', value);

  /// File size in bytes
  int? get fileSize {
    final sizeStr = event.getFirstTagValue('size');
    return sizeStr != null ? int.tryParse(sizeStr) : null;
  }

  /// Sets the file size in bytes
  set fileSize(int? value) => event.setTagValue('size', value?.toString());

  /// Video duration in seconds
  int? get duration {
    final durationStr = event.getFirstTagValue('duration');
    return durationStr != null ? int.tryParse(durationStr) : null;
  }

  /// Sets the video duration in seconds
  set duration(int? value) => event.setTagValue('duration', value?.toString());

  /// Thumbnail image URL
  String? get thumbnailUrl => event.getFirstTagValue('thumb');

  /// Sets the thumbnail image URL
  set thumbnailUrl(String? value) => event.setTagValue('thumb', value);

  /// Alternative text for accessibility
  String? get altText => event.getFirstTagValue('alt');

  /// Sets the alternative text for accessibility
  set altText(String? value) => event.setTagValue('alt', value);

  /// Hashtags associated with this video
  Set<String> get hashtags => event.getTagSetValues('t');

  /// Sets the hashtags associated with this video
  set hashtags(Set<String> value) => event.setTagValues('t', value);

  /// Adds a hashtag
  void addHashtag(String? value) => event.addTagValue('t', value);

  /// Removes a hashtag
  void removeHashtag(String? value) => event.removeTagWithValue('t', value);

  /// Location where the video was recorded
  String? get location => event.getFirstTagValue('location');

  /// Sets the location where the video was recorded
  set location(String? value) => event.setTagValue('location', value);

  /// Geohash for location-based queries
  String? get geohash => event.getFirstTagValue('g');

  /// Sets the geohash for location-based queries
  set geohash(String? value) => event.setTagValue('g', value);

  /// Video title
  String? get title => event.getFirstTagValue('title');

  /// Sets the video title
  set title(String? value) => event.setTagValue('title', value);

  /// Summary or brief description
  String? get summary => event.getFirstTagValue('summary');

  /// Sets the summary or brief description
  set summary(String? value) => event.setTagValue('summary', value);
}

/// Create and sign new video events.
///
/// Example usage:
/// ```dart
/// final video = await PartialVideo(
///   videoUrl: 'https://example.com/video.mp4',
///   description: 'Amazing sunset timelapse',
///   title: 'Sunset Timelapse',
///   hashtags: {'sunset', 'timelapse', 'nature'},
/// ).signWith(signer);
/// ```
class PartialVideo extends RegularPartialModel<Video> with PartialVideoMixin {
  PartialVideo.fromMap(super.map) : super.fromMap();

  /// Creates a new video event
  ///
  /// [videoUrl] - The primary video URL (required)
  /// [description] - Video description or caption (optional)
  /// [title] - Video title (optional)
  /// [altText] - Alternative text for accessibility (optional)
  /// [hashtags] - Set of hashtags (optional)
  /// [location] - Location where video was recorded (optional)
  /// [mimeType] - Video MIME type (optional)
  /// [fileSize] - File size in bytes (optional)
  /// [duration] - Video duration in seconds (optional)
  /// [dimensions] - Video dimensions as "widthxheight" (optional)
  /// [videoHash] - File hash for verification (optional)
  /// [thumbnailUrl] - Thumbnail image URL (optional)
  /// [summary] - Brief description or summary (optional)
  PartialVideo({
    required String videoUrl,
    String? description,
    String? title,
    String? altText,
    Set<String>? hashtags,
    String? location,
    String? mimeType,
    int? fileSize,
    int? duration,
    String? dimensions,
    String? videoHash,
    String? thumbnailUrl,
    String? summary,
  }) {
    this.videoUrl = videoUrl;
    if (description != null) this.description = description;
    if (title != null) this.title = title;
    if (altText != null) this.altText = altText;
    if (hashtags != null) this.hashtags = hashtags;
    if (location != null) this.location = location;
    if (mimeType != null) this.mimeType = mimeType;
    if (fileSize != null) this.fileSize = fileSize;
    if (duration != null) this.duration = duration;
    if (dimensions != null) this.dimensions = dimensions;
    if (videoHash != null) this.videoHash = videoHash;
    if (thumbnailUrl != null) this.thumbnailUrl = thumbnailUrl;
    if (summary != null) this.summary = summary;
  }

  /// Creates a video with width and height dimensions
  ///
  /// [videoUrl] - The primary video URL (required)
  /// [width] - Video width in pixels (required)
  /// [height] - Video height in pixels (required)
  /// [description] - Video description or caption (optional)
  /// [title] - Video title (optional)
  /// [altText] - Alternative text for accessibility (optional)
  /// [hashtags] - Set of hashtags (optional)
  /// [location] - Location where video was recorded (optional)
  /// [mimeType] - Video MIME type (optional)
  /// [fileSize] - File size in bytes (optional)
  /// [duration] - Video duration in seconds (optional)
  /// [videoHash] - File hash for verification (optional)
  /// [thumbnailUrl] - Thumbnail image URL (optional)
  /// [summary] - Brief description or summary (optional)
  PartialVideo.withDimensions({
    required String videoUrl,
    required int width,
    required int height,
    String? description,
    String? title,
    String? altText,
    Set<String>? hashtags,
    String? location,
    String? mimeType,
    int? fileSize,
    int? duration,
    String? videoHash,
    String? thumbnailUrl,
    String? summary,
  }) : this(
         videoUrl: videoUrl,
         dimensions: '${width}x$height',
         description: description,
         title: title,
         altText: altText,
         hashtags: hashtags,
         location: location,
         mimeType: mimeType,
         fileSize: fileSize,
         duration: duration,
         videoHash: videoHash,
         thumbnailUrl: thumbnailUrl,
         summary: summary,
       );
}

/// Create and sign new short-form portrait video events.
///
/// Example usage:
/// ```dart
/// final shortVideo = await PartialShortFormPortraitVideo(
///   videoUrl: 'https://example.com/short-video.mp4',
///   description: 'Quick dance video!',
///   hashtags: {'dance', 'shortform', 'viral'},
/// ).signWith(signer);
/// ```
class PartialShortFormPortraitVideo
    extends RegularPartialModel<ShortFormPortraitVideo>
    with PartialShortFormPortraitVideoMixin {
  PartialShortFormPortraitVideo.fromMap(super.map) : super.fromMap();

  /// Creates a new short-form portrait video event
  ///
  /// [videoUrl] - The primary video URL (required)
  /// [description] - Video description or caption (optional)
  /// [title] - Video title (optional)
  /// [altText] - Alternative text for accessibility (optional)
  /// [hashtags] - Set of hashtags (optional)
  /// [location] - Location where video was recorded (optional)
  /// [mimeType] - Video MIME type (optional)
  /// [fileSize] - File size in bytes (optional)
  /// [duration] - Video duration in seconds (optional)
  /// [dimensions] - Video dimensions as "widthxheight" (should be portrait) (optional)
  /// [videoHash] - File hash for verification (optional)
  /// [thumbnailUrl] - Thumbnail image URL (optional)
  /// [summary] - Brief description or summary (optional)
  PartialShortFormPortraitVideo({
    required String videoUrl,
    String? description,
    String? title,
    String? altText,
    Set<String>? hashtags,
    String? location,
    String? mimeType,
    int? fileSize,
    int? duration,
    String? dimensions,
    String? videoHash,
    String? thumbnailUrl,
    String? summary,
  }) {
    this.videoUrl = videoUrl;
    if (description != null) this.description = description;
    if (title != null) this.title = title;
    if (altText != null) this.altText = altText;
    if (hashtags != null) this.hashtags = hashtags;
    if (location != null) this.location = location;
    if (mimeType != null) this.mimeType = mimeType;
    if (fileSize != null) this.fileSize = fileSize;
    if (duration != null) this.duration = duration;
    if (dimensions != null) this.dimensions = dimensions;
    if (videoHash != null) this.videoHash = videoHash;
    if (thumbnailUrl != null) this.thumbnailUrl = thumbnailUrl;
    if (summary != null) this.summary = summary;
  }

  /// Creates a portrait video with width and height dimensions
  ///
  /// [videoUrl] - The primary video URL (required)
  /// [width] - Video width in pixels (required, should be less than height)
  /// [height] - Video height in pixels (required, should be greater than width)
  /// [description] - Video description or caption (optional)
  /// [title] - Video title (optional)
  /// [altText] - Alternative text for accessibility (optional)
  /// [hashtags] - Set of hashtags (optional)
  /// [location] - Location where video was recorded (optional)
  /// [mimeType] - Video MIME type (optional)
  /// [fileSize] - File size in bytes (optional)
  /// [duration] - Video duration in seconds (optional)
  /// [videoHash] - File hash for verification (optional)
  /// [thumbnailUrl] - Thumbnail image URL (optional)
  /// [summary] - Brief description or summary (optional)
  PartialShortFormPortraitVideo.withDimensions({
    required String videoUrl,
    required int width,
    required int height,
    String? description,
    String? title,
    String? altText,
    Set<String>? hashtags,
    String? location,
    String? mimeType,
    int? fileSize,
    int? duration,
    String? videoHash,
    String? thumbnailUrl,
    String? summary,
  }) : this(
         videoUrl: videoUrl,
         dimensions: '${width}x$height',
         description: description,
         title: title,
         altText: altText,
         hashtags: hashtags,
         location: location,
         mimeType: mimeType,
         fileSize: fileSize,
         duration: duration,
         videoHash: videoHash,
         thumbnailUrl: thumbnailUrl,
         summary: summary,
       );
}

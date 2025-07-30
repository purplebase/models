part of models;

/// A picture event (kind 20) for sharing images in picture-first feeds.
///
/// Picture events are designed for image-centric social media experiences,
/// similar to Instagram posts. They include the image URL, description,
/// and optional metadata about the image.
class Picture extends RegularModel<Picture> {
  /// Notes that reference this picture
  late final HasMany<Note> referencingNotes;

  /// Comments on this picture
  late final HasMany<Comment> comments;

  Picture.fromMap(super.map, super.ref) : super.fromMap() {
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
          '#e': {event.id},
        },
      ).toRequest(),
    );
  }

  /// The image description or caption
  String get description => event.content;

  /// The primary image URL
  String? get imageUrl {
    // First try to get URL from imeta tags (NIP-68)
    final imetaUrls = Utils.extractImetaUrls(event.getTagSet('imeta'));
    if (imetaUrls.isNotEmpty) return imetaUrls.first;

    // Fall back to simple url tags
    return event.getFirstTagValue('url');
  }

  /// Alternative image URLs for different resolutions
  Set<String> get altImageUrls => event.getTagSetValues('url').skip(1).toSet();

  /// All image URLs (primary + alternatives)
  Set<String> get allImageUrls {
    final urls = <String>{};

    // Add URLs from imeta tags (NIP-68)
    urls.addAll(Utils.extractImetaUrls(event.getTagSet('imeta')));

    // Add URLs from simple url tags
    urls.addAll(event.getTagSetValues('url'));

    return urls;
  }

  /// The image file hash for verification
  String? get imageHash => event.getFirstTagValue('x');

  /// Image dimensions in format "widthxheight"
  String? get dimensions => event.getFirstTagValue('dim');

  /// Image width in pixels
  int? get width {
    final dim = dimensions;
    if (dim == null) return null;
    final parts = dim.split('x');
    return parts.isNotEmpty ? int.tryParse(parts[0]) : null;
  }

  /// Image height in pixels
  int? get height {
    final dim = dimensions;
    if (dim == null) return null;
    final parts = dim.split('x');
    return parts.length > 1 ? int.tryParse(parts[1]) : null;
  }

  /// Image MIME type
  String? get mimeType => event.getFirstTagValue('m');

  /// File size in bytes
  int? get fileSize {
    final sizeStr = event.getFirstTagValue('size');
    return sizeStr != null ? int.tryParse(sizeStr) : null;
  }

  /// Alternative text for accessibility
  String? get altText => event.getFirstTagValue('alt');

  /// Hashtags associated with this picture
  Set<String> get hashtags => event.getTagSetValues('t');

  /// Location where the picture was taken
  String? get location => event.getFirstTagValue('location');

  /// Geohash for location-based queries
  String? get geohash => event.getFirstTagValue('g');

  /// Whether this picture has location information
  bool get hasLocation => location != null || geohash != null;

  /// Whether this picture has accessibility text
  bool get hasAltText => altText != null && altText!.isNotEmpty;
}

/// Generated partial model mixin for Picture
mixin PartialPictureMixin on RegularPartialModel<Picture> {
  /// The image description or caption
  String? get description => event.content.isEmpty ? null : event.content;

  /// Sets the image description or caption
  set description(String? value) => event.content = value ?? '';

  /// The primary image URL
  String? get imageUrl {
    // First try to get URL from imeta tags (NIP-68)
    final imetaUrls = Utils.extractImetaUrls(event.getTagSet('imeta'));
    if (imetaUrls.isNotEmpty) return imetaUrls.first;

    // Fall back to simple url tags
    return event.getFirstTagValue('url');
  }

  /// Sets the primary image URL
  set imageUrl(String? value) => event.setTagValue('url', value);

  /// All image URLs (primary + alternatives)
  Set<String> get allImageUrls {
    final urls = <String>{};

    // Add URLs from imeta tags (NIP-68)
    urls.addAll(Utils.extractImetaUrls(event.getTagSet('imeta')));

    // Add URLs from simple url tags
    urls.addAll(event.getTagSetValues('url'));

    return urls;
  }

  /// Sets all image URLs
  set allImageUrls(Set<String> value) => event.setTagValues('url', value);

  /// Adds an image URL
  void addImageUrl(String? value) => event.addTagValue('url', value);

  /// Removes an image URL
  void removeImageUrl(String? value) => event.removeTagWithValue('url', value);

  /// The image file hash for verification
  String? get imageHash => event.getFirstTagValue('x');

  /// Sets the image file hash
  set imageHash(String? value) => event.setTagValue('x', value);

  /// Image dimensions in format "widthxheight"
  String? get dimensions => event.getFirstTagValue('dim');

  /// Sets the image dimensions
  set dimensions(String? value) => event.setTagValue('dim', value);

  /// Image MIME type
  String? get mimeType => event.getFirstTagValue('m');

  /// Sets the image MIME type
  set mimeType(String? value) => event.setTagValue('m', value);

  /// File size in bytes
  int? get fileSize {
    final sizeStr = event.getFirstTagValue('size');
    return sizeStr != null ? int.tryParse(sizeStr) : null;
  }

  /// Sets the file size in bytes
  set fileSize(int? value) => event.setTagValue('size', value?.toString());

  /// Alternative text for accessibility
  String? get altText => event.getFirstTagValue('alt');

  /// Sets the alternative text for accessibility
  set altText(String? value) => event.setTagValue('alt', value);

  /// Hashtags associated with this picture
  Set<String> get hashtags => event.getTagSetValues('t');

  /// Sets the hashtags associated with this picture
  set hashtags(Set<String> value) => event.setTagValues('t', value);

  /// Adds a hashtag
  void addHashtag(String? value) => event.addTagValue('t', value);

  /// Removes a hashtag
  void removeHashtag(String? value) => event.removeTagWithValue('t', value);

  /// Location where the picture was taken
  String? get location => event.getFirstTagValue('location');

  /// Sets the location where the picture was taken
  set location(String? value) => event.setTagValue('location', value);

  /// Geohash for location-based queries
  String? get geohash => event.getFirstTagValue('g');

  /// Sets the geohash for location-based queries
  set geohash(String? value) => event.setTagValue('g', value);
}

/// Create and sign new picture events.
///
/// Example usage:
/// ```dart
/// final picture = await PartialPicture(
///   imageUrl: 'https://example.com/image.jpg',
///   description: 'Beautiful sunset at the beach',
///   hashtags: {'sunset', 'beach', 'photography'},
/// ).signWith(signer);
/// ```
class PartialPicture extends RegularPartialModel<Picture>
    with PartialPictureMixin {
  PartialPicture.fromMap(super.map) : super.fromMap();

  /// Creates a new picture event
  ///
  /// [imageUrl] - The primary image URL (required)
  /// [description] - Image description or caption (optional)
  /// [altText] - Alternative text for accessibility (optional)
  /// [hashtags] - Set of hashtags (optional)
  /// [location] - Location where picture was taken (optional)
  /// [mimeType] - Image MIME type (optional)
  /// [fileSize] - File size in bytes (optional)
  /// [dimensions] - Image dimensions as "widthxheight" (optional)
  /// [imageHash] - File hash for verification (optional)
  PartialPicture({
    required String imageUrl,
    String? description,
    String? altText,
    Set<String>? hashtags,
    String? location,
    String? mimeType,
    int? fileSize,
    String? dimensions,
    String? imageHash,
  }) {
    this.imageUrl = imageUrl;
    if (description != null) this.description = description;
    if (altText != null) this.altText = altText;
    if (hashtags != null) this.hashtags = hashtags;
    if (location != null) this.location = location;
    if (mimeType != null) this.mimeType = mimeType;
    if (fileSize != null) this.fileSize = fileSize;
    if (dimensions != null) this.dimensions = dimensions;
    if (imageHash != null) this.imageHash = imageHash;
  }

  /// Creates a picture with width and height dimensions
  ///
  /// [imageUrl] - The primary image URL (required)
  /// [width] - Image width in pixels (required)
  /// [height] - Image height in pixels (required)
  /// [description] - Image description or caption (optional)
  /// [altText] - Alternative text for accessibility (optional)
  /// [hashtags] - Set of hashtags (optional)
  /// [location] - Location where picture was taken (optional)
  /// [mimeType] - Image MIME type (optional)
  /// [fileSize] - File size in bytes (optional)
  /// [imageHash] - File hash for verification (optional)
  PartialPicture.withDimensions({
    required String imageUrl,
    required int width,
    required int height,
    String? description,
    String? altText,
    Set<String>? hashtags,
    String? location,
    String? mimeType,
    int? fileSize,
    String? imageHash,
  }) : this(
         imageUrl: imageUrl,
         dimensions: '${width}x$height',
         description: description,
         altText: altText,
         hashtags: hashtags,
         location: location,
         mimeType: mimeType,
         fileSize: fileSize,
         imageHash: imageHash,
       );
}

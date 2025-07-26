part of models;

/// A long-form article event (kind 30023) for publishing structured content.
///
/// Articles are parameterizable replaceable events that support rich content
/// with titles, summaries, images, and markdown formatting. They're designed
/// for blog posts, documentation, and other long-form content.
class Article extends ParameterizableReplaceableModel<Article> {
  Article.fromMap(super.map, super.ref) : super.fromMap() {
    highlights = HasMany(
      ref,
      RequestFilter<Highlight>(
        tags: {
          'a': {event.id},
        },
      ).toRequest(),
    );

    reposts = HasMany(
      ref,
      RequestFilter<GenericRepost>(
        tags: {
          '#a': {event.id},
        },
      ).toRequest(),
    );
  }

  /// The article title
  String? get title => event.getFirstTagValue('title');

  /// The full markdown content of the article
  String get content => event.content;

  /// URL-friendly identifier for the article
  String get slug => event.getFirstTagValue('d')!;

  /// URL to the header image for the article
  String? get imageUrl => event.getFirstTagValue('image');

  /// Brief description or summary of the article
  String? get summary => event.getFirstTagValue('summary');

  /// When the article was published (may differ from created_at)
  DateTime? get publishedAt =>
      event.getFirstTagValue('published_at')?.toInt()?.toDate();

  late final HasMany<Highlight> highlights;
  late final HasMany<GenericRepost> reposts;
}

/// Generated partial model mixin for Article
mixin PartialArticleMixin on ParameterizableReplaceablePartialModel<Article> {
  /// The article title
  String? get title => event.getFirstTagValue('title');

  /// Sets the article title
  set title(String? value) => event.setTagValue('title', value);

  /// The full content of the article
  String? get content => event.content.isEmpty ? null : event.content;

  /// Sets the article content
  set content(String? value) => event.content = value ?? '';

  /// URL-friendly identifier for the article
  String? get slug => event.getFirstTagValue('d');

  /// Sets the article slug
  set slug(String? value) => event.setTagValue('d', value);

  /// URL to the header image
  String? get imageUrl => event.getFirstTagValue('image');

  /// Sets the header image URL
  set imageUrl(String? value) => event.setTagValue('image', value);

  /// Brief description or summary
  String? get summary => event.getFirstTagValue('summary');

  /// Sets the article summary
  set summary(String? value) => event.setTagValue('summary', value);

  /// When the article was published
  DateTime? get publishedAt =>
      event.getFirstTagValue('published_at')?.toInt()?.toDate();

  /// Sets the publication timestamp
  set publishedAt(DateTime? value) =>
      event.setTagValue('published_at', value?.toSeconds().toString());
}

/// Create and sign new article events.
///
/// Example usage:
/// ```dart
/// final article = await PartialArticle('My Article', 'Article content...').signWith(signer);
/// ```
class PartialArticle extends ParameterizableReplaceablePartialModel<Article>
    with PartialArticleMixin {
  PartialArticle.fromMap(super.map) : super.fromMap();

  /// Creates a new article with the specified title and content
  ///
  /// [title] - The article title (required)
  /// [content] - The full markdown content (required)
  /// [publishedAt] - Optional publication timestamp
  /// [slug] - Optional URL-friendly identifier (random if not provided)
  /// [imageUrl] - Optional header image URL
  /// [summary] - Optional brief description
  PartialArticle(
    String title,
    String content, {
    DateTime? publishedAt,
    String? slug,
    String? imageUrl,
    String? summary,
  }) {
    this.title = title;
    this.publishedAt = publishedAt;
    this.slug = slug ?? Utils.generateRandomHex64();
    this.imageUrl = imageUrl;
    this.summary = summary;
    this.content = content;
  }
}

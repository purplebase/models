part of models;

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
  }

  String? get title => event.getFirstTagValue('title');
  String get content => event.content;
  String get slug => event.getFirstTagValue('d')!;
  String? get imageUrl => event.getFirstTagValue('image');
  String? get summary => event.getFirstTagValue('summary');
  DateTime? get publishedAt =>
      event.getFirstTagValue('published_at')?.toInt()?.toDate();

  late final HasMany<Highlight> highlights;
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for Article
mixin PartialArticleMixin on ParameterizableReplaceablePartialModel<Article> {
  String? get title => event.getFirstTagValue('title');
  set title(String? value) => event.setTagValue('title', value);
  String? get content => event.content.isEmpty ? null : event.content;
  set content(String? value) => event.content = value ?? '';
  String? get slug => event.getFirstTagValue('d');
  set slug(String? value) => event.setTagValue('d', value);
  String? get imageUrl => event.getFirstTagValue('image');
  set imageUrl(String? value) => event.setTagValue('image', value);
  String? get summary => event.getFirstTagValue('summary');
  set summary(String? value) => event.setTagValue('summary', value);
  DateTime? get publishedAt =>
      event.getFirstTagValue('published_at')?.toInt()?.toDate();
  set publishedAt(DateTime? value) =>
      event.setTagValue('published_at', value?.toSeconds().toString());
}

class PartialArticle extends ParameterizableReplaceablePartialModel<Article>
    with PartialArticleMixin {
  PartialArticle.fromMap(super.map) : super.fromMap();

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

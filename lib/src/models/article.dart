part of models;

class Article extends ParameterizableReplaceableModel<Article> {
  Article.fromMap(super.map, super.ref) : super.fromMap();
  String? get title => event.getFirstTagValue('title');
  String get content => event.content;
  String get slug => event.getFirstTagValue('d')!;
  String? get imageUrl => event.getFirstTagValue('image');
  String? get summary => event.getFirstTagValue('summary');
  DateTime? get publishedAt =>
      event.getFirstTagValue('published_at')?.toInt()?.toDate();

  PartialArticle copyWith({
    String? title,
    String? content,
    String? imageUrl,
    String? summary,
    DateTime? publishedAt,
  }) {
    return PartialArticle(
      title ?? this.title ?? '',
      content ?? event.content,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }
}

class PartialArticle extends ParameterizableReplaceablePartialEvent<Article> {
  PartialArticle(String title, String content,
      {DateTime? publishedAt,
      String? slug,
      String? imageUrl,
      String? summary}) {
    this.title = title;
    this.publishedAt = publishedAt;
    this.slug = slug ?? Utils.generateRandomHex64();
    this.imageUrl = imageUrl;
    this.summary = summary;
    event.content = content;
  }
  set title(String value) => event.addTagValue('title', value);
  set slug(String value) => event.addTagValue('d', value);
  set content(String value) => event.content = value;
  set publishedAt(DateTime? value) =>
      event.addTagValue('published_at', value?.toSeconds().toString());
  set imageUrl(String? value) => event.addTagValue('image', value);
  set summary(String? value) => event.addTagValue('summary', value);
}

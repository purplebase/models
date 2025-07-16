part of models;

@GeneratePartialModel()
class Article extends ParameterizableReplaceableModel<Article> {
  Article.fromMap(super.map, super.ref) : super.fromMap();

  String? get title => event.getFirstTagValue('title');
  String get content => event.content;
  String get slug => event.getFirstTagValue('d')!;
  String? get imageUrl => event.getFirstTagValue('image');
  String? get summary => event.getFirstTagValue('summary');
  DateTime? get publishedAt =>
      event.getFirstTagValue('published_at')?.toInt()?.toDate();
}

class PartialArticle extends ParameterizableReplaceablePartialModel<Article>
    with PartialArticleMixin {
  PartialArticle.fromMap(super.map) : super.fromMap();

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
    this.content = content;
  }
}

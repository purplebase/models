part of models;

class Article extends ParameterizableReplaceableModel<Article> {
  Article.fromMap(super.map, super.ref) : super.fromMap();
  String? get title => event.getFirstTagValue('title');
  String? get imageUrl => event.getFirstTagValue('image');
  String? get summary => event.getFirstTagValue('summary');
  DateTime? get publishedAt =>
      event.getFirstTagValue('published_at')?.toInt()?.toDate();

  PartialArticle copyWith({
    String? title,
    String? content, // Required by PartialArticle constructor
    String? imageUrl, // Not settable via PartialArticle constructor
    String? summary, // Not settable via PartialArticle constructor
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
  PartialArticle(String title, String content, {DateTime? publishedAt}) {
    event.content = content;
    event.addTagValue('title', title);
    event.addTagValue('published_at', publishedAt?.toSeconds().toString());
  }
}

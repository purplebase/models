part of models;

class Article extends ParameterizableReplaceableModel<Article> {
  Article.fromMap(super.map, super.ref) : super.fromMap();
  String? get title => event.getFirstTagValue('title');
  String? get imageUrl => event.getFirstTagValue('image');
  String? get summary => event.getFirstTagValue('summary');
  DateTime? get publishedAt =>
      event.getFirstTagValue('published_at')?.toInt()?.toDate();
}

class PartialArticle extends ParameterizableReplaceablePartialEvent<Article> {
  PartialArticle(String title, String content, {DateTime? publishedAt}) {
    event.content = content;
    event.addTagValue('title', title);
    event.addTagValue('published_at', publishedAt?.toSeconds().toString());
  }
}

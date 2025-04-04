import 'package:models/models.dart';

class Article extends ParameterizableReplaceableEvent<Article> {
  Article.fromMap(super.map, super.ref) : super.fromMap();
  String? get title => internal.getFirstTagValue('title');
  String? get imageUrl => internal.getFirstTagValue('image');
  String? get summary => internal.getFirstTagValue('summary');
  DateTime? get publishedAt =>
      internal.getFirstTagValue('published_at')?.toInt()?.toDate();
}

class PartialArticle extends ParameterizableReplaceablePartialEvent<Article> {
  PartialArticle(String title, String content, {DateTime? publishedAt}) {
    internal.content = content;
    internal.addTagValue('title', title);
    internal.addTagValue('published_at', publishedAt?.toSeconds().toString());
  }
}

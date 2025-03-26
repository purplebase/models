import 'package:models/models.dart';
import 'package:models/src/core/utils.dart';

class Article extends ParameterizableReplaceableEvent<Article> {
  Article.fromMap(super.map, super.ref) : super.fromMap();
  // final List<Reaction>? reactions;
  // final List<Zap>? zaps;
}

class PartialArticle extends ParameterizableReplaceablePartialEvent<Article> {
  PartialArticle(String title, String content, {DateTime? publishedAt}) {
    internal.content = content;
    internal.addTagValue('title', title);
    internal.addTagValue('published_at', publishedAt?.toSeconds().toString());
  }
}

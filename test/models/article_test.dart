import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;

  setUpAll(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
  });

  group('Article', () {
    test('article', () {
      final article = PartialArticle(
        'title',
        'Content of the article',
        slug: 'yo',
        summary: 'summary',
        publishedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ).dummySign(verbirichaPubkey);
      expect(article.imageUrl, isNull);
      expect(article.slug, 'yo');
      expect(article.title, 'title');
    });
  });
}

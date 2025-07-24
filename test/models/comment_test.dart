import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    storage =
        container.read(storageNotifierProvider.notifier)
            as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.cancel();
    await storage.clear();
    container.dispose();
  });

  group('Comment', () {
    test('comment', () async {
      // Create test content to comment on
      final article = PartialArticle(
        'Test Article',
        'Article content for testing comments',
        slug: 'test-article',
        summary: 'Test article summary',
      ).dummySign(nielPubkey);

      final fileMetadata = PartialFileMetadata().dummySign(franzapPubkey);

      // Create comments on different content types
      final articleComment = PartialComment(
        content: 'Comment on an article',
        rootModel: article,
        parentModel: article,
      ).dummySign(verbirichaPubkey);

      final fileComment = PartialComment(
        content: 'Comment on a file',
        rootModel: fileMetadata,
        parentModel: fileMetadata,
      ).dummySign(nielPubkey);

      // Save base models first
      await storage.save({article, fileMetadata});

      // Save comments on root content
      await storage.save({articleComment, fileComment});

      // Create a reply to a comment (nested comment) - create manually instead of using helper
      final nestedComment = PartialComment(
        content: 'Reply to the article comment',
        rootModel: article,
        parentModel: articleComment,
      ).dummySign(franzapPubkey);

      // Save nested comment separately
      await storage.save({nestedComment});

      // Test comment on article
      expect(articleComment.content, 'Comment on an article');
      expect(articleComment.rootModel.value, article);
      expect(articleComment.parentModel.value, article);
      expect(articleComment.rootKind, article.event.kind);
      expect(articleComment.parentKind, article.event.kind);
      expect(articleComment.rootAuthor.value, article.author.value);
      expect(articleComment.parentAuthor.value, article.author.value);

      // Test comment on file
      expect(fileComment.content, 'Comment on a file');
      expect(fileComment.rootModel.value, fileMetadata);
      expect(fileComment.parentModel.value, fileMetadata);
      expect(fileComment.rootKind, fileMetadata.event.kind);
      expect(fileComment.parentKind, fileMetadata.event.kind);
      expect(fileComment.rootAuthor.value, fileMetadata.author.value);
      expect(fileComment.parentAuthor.value, fileMetadata.author.value);

      // Test nested comment (reply to comment)
      expect(nestedComment.content, 'Reply to the article comment');
      expect(nestedComment.rootModel.value, article); // Same root as parent
      expect(
        nestedComment.parentModel.value,
        articleComment,
      ); // Parent is the first comment
      expect(nestedComment.rootKind, article.event.kind);
      expect(nestedComment.parentKind, 1111); // Parent kind is 1111 (Comment)
      expect(nestedComment.rootAuthor.value, article.author.value);
      expect(nestedComment.parentAuthor.value, articleComment.author.value);

      // Test relationship from article to comments
      final commentFromArticle = await container
          .read(storageNotifierProvider.notifier)
          .query(
            RequestFilter(
              kinds: {1111},
              tags: {
                '#A': {article.id},
              },
            ).toRequest(),
          );

      expect(commentFromArticle, contains(articleComment));

      // Test relationship from article comment to its replies
      expect(articleComment.replies.toList(), contains(nestedComment));

      // Test external URI comments
      final externalComment = PartialComment(
        content: 'Comment on external content',
        externalRootUri: 'https://example.com/article/123',
        externalParentUri: 'https://example.com/article/123',
      ).dummySign(nielPubkey);

      await storage.save({externalComment});

      expect(
        externalComment.externalRootUri,
        'https://example.com/article/123',
      );
      expect(
        externalComment.externalParentUri,
        'https://example.com/article/123',
      );
    });
  });
}

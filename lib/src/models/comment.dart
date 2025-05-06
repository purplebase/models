part of models;

/// Comment represents a comment (kind 1111) on various types of content as specified in NIP-22.
/// It provides a structured approach for commenting on long-form articles, files,
/// and other non-text-note content with clear parent-child relationships.
class Comment extends RegularModel<Comment> {
  /// Content being replied to (root)
  late final BelongsTo<Article> rootArticle;
  late final BelongsTo<FileMetadata> rootFile;

  /// Direct parent - could be the root content or another comment
  late final BelongsTo<Article> parentArticle;
  late final BelongsTo<FileMetadata> parentFile;
  late final BelongsTo<Comment> parentComment;

  /// Author of the root content
  late final BelongsTo<Profile> rootAuthor;

  /// Author of the parent content
  late final BelongsTo<Profile> parentAuthor;

  /// Child replies to this comment
  late final HasMany<Comment> replies;

  Comment.fromMap(super.map, super.ref) : super.fromMap() {
    // Initialize root content relationships
    String? rootId;

    // Root article reference (replaceable)
    if (event.containsTag('A')) {
      rootId = event.getFirstTagValue('A');
      rootArticle = BelongsTo(
          ref, rootId != null ? RequestFilter.fromReplaceable(rootId) : null);
    } else {
      rootArticle = BelongsTo(ref, null);
    }

    // Root file or other regular event reference
    if (event.containsTag('E')) {
      rootId = event.getFirstTagValue('E');
      rootFile = BelongsTo(ref,
          rootId != null ? RequestFilter<FileMetadata>(ids: {rootId}) : null);
    } else {
      rootFile = BelongsTo(ref, null);
    }

    // Initialize parent content relationships
    String? parentId;

    // Parent article reference (replaceable)
    if (event.containsTag('a')) {
      parentId = event.getFirstTagValue('a');
      parentArticle = BelongsTo(ref,
          parentId != null ? RequestFilter.fromReplaceable(parentId) : null);
    } else {
      parentArticle = BelongsTo(ref, null);
    }

    // Parent event reference (could be comment or file)
    if (event.containsTag('e')) {
      parentId = event.getFirstTagValue('e');
      // Determine if parent is a comment (kind 1111) or file based on k tag
      final parentKindStr = event.getFirstTagValue('k');
      final parentKind = int.tryParse(parentKindStr ?? '');

      if (parentKind == 1111) {
        parentComment = BelongsTo(ref,
            parentId != null ? RequestFilter<Comment>(ids: {parentId}) : null);
        parentFile = BelongsTo(ref, null);
      } else {
        parentFile = BelongsTo(
            ref,
            parentId != null
                ? RequestFilter<FileMetadata>(ids: {parentId})
                : null);
        parentComment = BelongsTo(ref, null);
      }
    } else {
      parentFile = BelongsTo(ref, null);
      parentComment = BelongsTo(ref, null);
    }

    // Root author relationship
    rootAuthor = BelongsTo<Profile>(
        ref,
        event.containsTag('P')
            ? RequestFilter(authors: {event.getFirstTagValue('P')!})
            : null);

    // Parent author relationship
    parentAuthor = BelongsTo<Profile>(
        ref,
        event.containsTag('p')
            ? RequestFilter(authors: {event.getFirstTagValue('p')!})
            : null);

    // Child replies to this comment
    replies = HasMany<Comment>(
      ref,
      RequestFilter(
        tags: {
          '#e': {event.id}
        },
        kinds: {1111},
      ),
    );
  }

  /// The comment content
  String get content => event.content;

  /// The kind of the root content
  int? get rootKind {
    final kValue = event.getFirstTagValue('K');
    if (kValue == null) return null;

    // Check if it's a URL (for external content) or a number
    if (kValue.startsWith('http')) {
      return null;
    } else {
      return int.tryParse(kValue);
    }
  }

  /// The kind of the parent content
  int? get parentKind {
    final kValue = event.getFirstTagValue('k');
    if (kValue == null) return null;

    // Check if it's a URL (for external content) or a number
    if (kValue.startsWith('http')) {
      return null;
    } else {
      return int.tryParse(kValue);
    }
  }

  /// For external content, gets the URI
  String? get externalRootUri =>
      event.getFirstTagValue('I') ??
      (event.getFirstTagValue('K')?.startsWith('http') == true
          ? event.getFirstTagValue('K')
          : null);

  /// For external content, gets the parent URI
  String? get externalParentUri =>
      event.getFirstTagValue('i') ??
      (event.getFirstTagValue('k')?.startsWith('http') == true
          ? event.getFirstTagValue('k')
          : null);

  /// Quoted event ID if this comment quotes another event
  String? get quotedEventId => event.getFirstTagValue('q');
}

class PartialComment extends RegularPartialModel<Comment> {
  PartialComment({
    required String content,
    Article? rootArticle,
    FileMetadata? rootFile,
    int? rootKind,
    Profile? rootAuthor,
    Article? parentArticle,
    FileMetadata? parentFile,
    Comment? parentComment,
    int? parentKind,
    Profile? parentAuthor,
    String? externalRootUri,
    String? externalParentUri,
    String? quotedEventId,
    DateTime? createdAt,
  }) {
    event.content = content;

    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    // Handle root content references
    if (rootArticle != null) {
      event.addTagValue('A', rootArticle.id);
      event.addTagValue('K', rootArticle.event.kind.toString());

      if (rootAuthor != null) {
        event.addTagValue('P', rootAuthor.pubkey);
      }
    } else if (rootFile != null) {
      event.addTagValue('E', rootFile.id);
      event.addTagValue('K', rootFile.event.kind.toString());

      if (rootAuthor != null) {
        event.addTagValue('P', rootAuthor.pubkey);
      }
    } else if (externalRootUri != null) {
      // External root reference
      event.addTagValue('I', externalRootUri);
      if (rootKind != null) {
        event.addTagValue('K', rootKind.toString());
      } else {
        // For external URLs, use the URL as the kind
        event.addTagValue('K', externalRootUri);
      }
    } else if (rootKind != null) {
      // Just set the kind if we have it
      event.addTagValue('K', rootKind.toString());
    }

    // Handle parent content references
    if (parentArticle != null) {
      event.addTagValue('a', parentArticle.id);
      event.addTagValue('k', parentArticle.event.kind.toString());

      if (parentAuthor != null) {
        event.addTagValue('p', parentAuthor.pubkey);
      }
    } else if (parentFile != null) {
      event.addTagValue('e', parentFile.id);
      event.addTagValue('k', parentFile.event.kind.toString());

      if (parentAuthor != null) {
        event.addTagValue('p', parentAuthor.pubkey);
      }
    } else if (parentComment != null) {
      event.addTagValue('e', parentComment.id);
      event.addTagValue('k', '1111');

      if (parentAuthor != null) {
        event.addTagValue('p', parentAuthor.pubkey);
      }
    } else if (externalParentUri != null) {
      // External parent reference
      event.addTagValue('i', externalParentUri);
      if (parentKind != null) {
        event.addTagValue('k', parentKind.toString());
      } else {
        // For external URLs, use the URL as the kind
        event.addTagValue('k', externalParentUri);
      }
    } else if (parentKind != null) {
      // Just set the kind if we have it
      event.addTagValue('k', parentKind.toString());
    }

    // Add quote reference if provided
    if (quotedEventId != null) {
      event.addTagValue('q', quotedEventId);
    }
  }

  /// Helper method to create a comment on an Article
  static PartialComment toArticle(Article article, String content) {
    return PartialComment(
      content: content,
      rootArticle: article,
      rootKind: article.event.kind,
      rootAuthor: article.author.value,
      parentArticle: article,
      parentKind: article.event.kind,
      parentAuthor: article.author.value,
    );
  }

  /// Helper method to create a comment on a FileMetadata
  static PartialComment toFileMetadata(FileMetadata file, String content) {
    return PartialComment(
      content: content,
      rootFile: file,
      rootKind: file.event.kind,
      rootAuthor: file.author.value,
      parentFile: file,
      parentKind: file.event.kind,
      parentAuthor: file.author.value,
    );
  }

  /// Helper method to create a comment on another comment, maintaining the proper thread hierarchy
  static PartialComment toComment(Comment parentComment, String content) {
    // Determine the original root content type
    Article? rootArticle = parentComment.rootArticle.value;
    FileMetadata? rootFile = parentComment.rootFile.value;
    int? rootKind = parentComment.rootKind;

    return PartialComment(
      content: content,
      // Keep the original root reference
      rootArticle: rootArticle,
      rootFile: rootFile,
      rootKind: rootKind,
      rootAuthor: parentComment.rootAuthor.value,
      // Set this comment as the parent
      parentComment: parentComment,
      parentKind: 1111,
      parentAuthor: parentComment.author.value,
    );
  }
}

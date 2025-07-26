part of models;

/// Comment represents a comment (kind 1111) on various types of content as specified in NIP-22.
/// It provides a structured approach for commenting on long-form articles, files,
/// and other non-text-note content with clear parent-child relationships.
class Comment extends RegularModel<Comment> {
  late final BelongsTo<Model> rootModel;
  late final BelongsTo<Model> parentModel;
  late final BelongsTo<Model> quotedModel;
  late final BelongsTo<Profile> rootAuthor;
  late final BelongsTo<Profile> parentAuthor;
  late final HasMany<Comment> replies;

  Comment.fromMap(super.map, super.ref) : super.fromMap() {
    // Root reference
    if (event.containsTag('A')) {
      rootModel = BelongsTo(
        ref,
        Request<Model>.fromIds({event.getFirstTagValue('A')!}),
      );
    } else if (event.containsTag('E')) {
      rootModel = BelongsTo(
        ref,
        Request.fromIds({?event.getFirstTagValue('E')}),
      );
    } else {
      rootModel = BelongsTo(ref, null);
    }

    // Parent article reference
    parentModel = BelongsTo(
      ref,
      Request.fromIds({
        ?event.getFirstTagValue('e'),
        ?event.getFirstTagValue('a'),
      }),
    );

    quotedModel = BelongsTo(
      ref,
      Request.fromIds({?event.getFirstTagValue('q')}),
    );

    // Root author relationship
    rootAuthor = BelongsTo(
      ref,
      event.containsTag('P')
          ? RequestFilter<Profile>(
              authors: {event.getFirstTagValue('P')!},
            ).toRequest()
          : null,
    );

    // Parent author relationship
    parentAuthor = BelongsTo(
      ref,
      event.containsTag('p')
          ? RequestFilter<Profile>(
              authors: {event.getFirstTagValue('p')!},
            ).toRequest()
          : null,
    );

    // Child replies to this comment
    replies = HasMany(
      ref,
      RequestFilter<Comment>(
        tags: {
          '#e': {event.id},
        },
        kinds: {1111},
      ).toRequest(),
    );
  }

  /// The text content of the comment
  String get content => event.content;

  /// External URI for the root content (if not a Nostr event)
  String? get externalRootUri => event.getFirstTagValue('I');

  /// External URI for the parent content (if not a Nostr event)
  String? get externalParentUri => event.getFirstTagValue('i');

  /// Kind number of the root content
  int? get rootKind => event.getFirstTagValue('K').toInt();

  /// Kind number of the parent content
  int? get parentKind => event.getFirstTagValue('k').toInt();
}

/// Generated partial model mixin for Comment
mixin PartialCommentMixin on RegularPartialModel<Comment> {
  /// The text content of the comment
  String? get content => event.content.isEmpty ? null : event.content;

  /// Sets the comment text content
  set content(String? value) => event.content = value ?? '';

  /// External URI for the root content
  String? get externalRootUri => event.getFirstTagValue('I');

  /// Sets the external root URI
  set externalRootUri(String? value) => event.setTagValue('I', value);

  /// External URI for the parent content
  String? get externalParentUri => event.getFirstTagValue('i');

  /// Sets the external parent URI
  set externalParentUri(String? value) => event.setTagValue('i', value);

  /// Kind number of the root content
  int? get rootKind => int.tryParse(event.getFirstTagValue('K') ?? '');

  /// Sets the root content kind
  set rootKind(int? value) => event.setTagValue('K', value?.toString());

  /// Kind number of the parent content
  int? get parentKind => int.tryParse(event.getFirstTagValue('k') ?? '');

  /// Sets the parent content kind
  set parentKind(int? value) => event.setTagValue('k', value?.toString());
}

/// Create and sign new comment events.
///
/// Example usage:
/// ```dart
/// final comment = await PartialComment(content: 'Great article!', rootModel: article).signWith(signer);
/// ```
class PartialComment extends RegularPartialModel<Comment>
    with PartialCommentMixin {
  PartialComment.fromMap(super.map) : super.fromMap();

  /// Creates a new comment on content
  ///
  /// [content] - The comment text (required)
  /// [rootModel] - The root content being commented on
  /// [parentModel] - The immediate parent content (for threaded comments)
  /// [externalRootUri] - External URI if commenting on non-Nostr content
  /// [externalParentUri] - External parent URI if applicable
  /// [quotedModel] - Content being quoted in the comment
  /// [createdAt] - Optional creation timestamp
  PartialComment({
    required String content,
    Model? rootModel,
    Model? parentModel,
    String? externalRootUri,
    String? externalParentUri,
    Model? quotedModel,
    DateTime? createdAt,
  }) {
    event.content = content;

    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    // Handle root content references
    // TODO [cache]: All calls to `value`/`toList` on relationships will break when removing sync db access
    if (rootModel is ReplaceableModel) {
      event.addTagValue('A', rootModel.id);
      event.addTagValue('K', rootModel.event.kind.toString());

      if (rootModel.author.value != null) {
        event.addTagValue('P', rootModel.author.value!.pubkey);
      }
    } else if (rootModel is RegularModel) {
      event.addTagValue('E', rootModel.id);
      event.addTagValue('K', rootModel.event.kind.toString());

      if (rootModel.author.value != null) {
        event.addTagValue('P', rootModel.author.value!.pubkey);
      }
    } else if (externalRootUri != null) {
      // External root reference
      event.addTagValue('I', externalRootUri);
    }

    // Handle parent content references
    if (parentModel is ReplaceableModel) {
      event.addTagValue('a', parentModel.id);
      event.addTagValue('k', parentModel.event.kind.toString());

      if (parentModel.author.value != null) {
        event.addTagValue('p', parentModel.author.value!.pubkey);
      }
    } else if (parentModel is RegularModel) {
      event.addTagValue('e', parentModel.id);
      event.addTagValue('k', parentModel.event.kind.toString());

      if (parentModel.author.value != null) {
        event.addTagValue('p', parentModel.author.value!.pubkey);
      }
    } else if (externalParentUri != null) {
      // External parent reference
      event.addTagValue('i', externalParentUri);
    }

    // Add quote reference if provided
    if (quotedModel != null) {
      event.addTagValue('q', quotedModel.id);
    }
  }
}

part of models;

/// Comment represents a comment (kind 1111) on various types of content as specified in NIP-22.
/// It provides a structured approach for commenting on long-form articles, files,
/// and other non-text-note content with clear parent-child relationships.
@GeneratePartialModel()
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
          ref, Request<Model>.fromIds({event.getFirstTagValue('A')!}));
    } else if (event.containsTag('E')) {
      rootModel = BelongsTo(
          ref,
          RequestFilter<Model>(ids: {event.getFirstTagValue('E')!})
              .toRequest());
    } else {
      rootModel = BelongsTo(ref, null);
    }

    // Parent article reference
    if (event.containsTag('a')) {
      parentModel = BelongsTo(
          ref, Request<Model>.fromIds({event.getFirstTagValue('a')!}));
    } else if (event.containsTag('e')) {
      parentModel = BelongsTo(
          ref,
          RequestFilter<Model>(ids: {event.getFirstTagValue('e')!})
              .toRequest());
    } else {
      parentModel = BelongsTo(ref, null);
    }

    if (event.containsTag('q')) {
      quotedModel = BelongsTo(
          ref,
          RequestFilter<Model>(ids: {event.getFirstTagValue('q')!})
              .toRequest());
    }

    // Root author relationship
    rootAuthor = BelongsTo(
        ref,
        event.containsTag('P')
            ? RequestFilter<Profile>(authors: {event.getFirstTagValue('P')!})
                .toRequest()
            : null);

    // Parent author relationship
    parentAuthor = BelongsTo(
        ref,
        event.containsTag('p')
            ? RequestFilter<Profile>(authors: {event.getFirstTagValue('p')!})
                .toRequest()
            : null);

    // Child replies to this comment
    replies = HasMany(
      ref,
      RequestFilter<Comment>(
        tags: {
          '#e': {event.id}
        },
        kinds: {1111},
      ).toRequest(),
    );
  }

  String get content => event.content;

  String? get externalRootUri => event.getFirstTagValue('I');
  String? get externalParentUri => event.getFirstTagValue('i');

  int? get rootKind => event.getFirstTagValue('K').toInt();
  int? get parentKind => event.getFirstTagValue('k').toInt();
}

class PartialComment extends RegularPartialModel<Comment> {
  PartialComment.fromMap(super.map) : super.fromMap();

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

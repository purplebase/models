// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// PartialModelGenerator
// **************************************************************************

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for App
mixin PartialAppMixin on ParameterizableReplaceablePartialEvent<App> {
  String? get name => event.getFirstTagValue('name');
  set name(String? value) => event.setTagValue('name', value);
  String? get summary => event.getFirstTagValue('summary');
  set summary(String? value) => event.setTagValue('summary', value);
  String? get repository => event.getFirstTagValue('repository');
  set repository(String? value) => event.setTagValue('repository', value);
  String? get description => event.content.isEmpty ? null : event.content;
  set description(String? value) => event.content = value ?? '';
  String? get url => event.getFirstTagValue('url');
  set url(String? value) => event.setTagValue('url', value);
  String? get license => event.getFirstTagValue('license');
  set license(String? value) => event.setTagValue('license', value);
  Set<String> get icons => event.getTagSetValues('icon');
  set icons(Set<String> value) => event.setTagValues('icon', value);
  void addIcon(String? value) => event.addTagValue('icon', value);
  void removeIcon(String? value) => event.removeTagWithValue('icon', value);
  Set<String> get images => event.getTagSetValues('image');
  set images(Set<String> value) => event.setTagValues('image', value);
  void addImage(String? value) => event.addTagValue('image', value);
  void removeImage(String? value) => event.removeTagWithValue('image', value);
  Set<String> get platforms => event.getTagSetValues('f');
  set platforms(Set<String> value) => event.setTagValues('f', value);
  void addPlatform(String? value) => event.addTagValue('f', value);
  void removePlatform(String? value) => event.removeTagWithValue('f', value);
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for Article
mixin PartialArticleMixin on ParameterizableReplaceablePartialEvent<Article> {
  String? get title => event.getFirstTagValue('title');
  set title(String? value) => event.setTagValue('title', value);
  String? get content => event.content.isEmpty ? null : event.content;
  set content(String? value) => event.content = value ?? '';
  String? get slug => event.getFirstTagValue('d');
  set slug(String? value) => event.setTagValue('d', value);
  String? get imageUrl => event.getFirstTagValue('image');
  set imageUrl(String? value) => event.setTagValue('image', value);
  String? get summary => event.getFirstTagValue('summary');
  set summary(String? value) => event.setTagValue('summary', value);
  DateTime? get publishedAt =>
      event.getFirstTagValue('published_at')?.toInt()?.toDate();
  set publishedAt(DateTime? value) =>
      event.setTagValue('published_at', value?.toSeconds().toString());
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for BlossomAuthorization
mixin PartialBlossomAuthorizationMixin
    on EphemeralPartialModel<BlossomAuthorization> {
  String? get content => event.content.isEmpty ? null : event.content;
  set content(String? value) => event.content = value ?? '';
  String? get hash => event.getFirstTagValue('x');
  set hash(String? value) => event.setTagValue('x', value);
  String? get mimeType => event.getFirstTagValue('m');
  set mimeType(String? value) => event.setTagValue('m', value);
  DateTime? get expiration =>
      event.getFirstTagValue('expiration')?.toInt()?.toDate();
  set expiration(DateTime? value) =>
      event.setTagValue('expiration', value?.toSeconds().toString());
  String? get server => event.getFirstTagValue('server');
  set server(String? value) => event.setTagValue('server', value);
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for ChatMessage
mixin PartialChatMessageMixin on RegularPartialModel<ChatMessage> {
  String? get content => event.content.isEmpty ? null : event.content;
  set content(String? value) => event.content = value ?? '';
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for Community
mixin PartialCommunityMixin on ReplaceablePartialModel<Community> {
  String? get name => event.getFirstTagValue('name');
  set name(String? value) => event.setTagValue('name', value);
  Set<String> get relayUrls => event.getTagSetValues('r');
  set relayUrls(Set<String> value) => event.setTagValues('r', value);
  void addRelayUrl(String? value) => event.addTagValue('r', value);
  void removeRelayUrl(String? value) => event.removeTagWithValue('r', value);
  String? get description => event.getFirstTagValue('description');
  set description(String? value) => event.setTagValue('description', value);
  Set<String> get blossomUrls => event.getTagSetValues('blossom');
  set blossomUrls(Set<String> value) => event.setTagValues('blossom', value);
  void addBlossomUrl(String? value) => event.addTagValue('blossom', value);
  void removeBlossomUrl(String? value) =>
      event.removeTagWithValue('blossom', value);
  Set<String> get cashuMintUrls => event.getTagSetValues('mint');
  set cashuMintUrls(Set<String> value) => event.setTagValues('mint', value);
  void addCashuMintUrl(String? value) => event.addTagValue('mint', value);
  void removeCashuMintUrl(String? value) =>
      event.removeTagWithValue('mint', value);
  String? get termsOfService => event.getFirstTagValue('tos');
  set termsOfService(String? value) => event.setTagValue('tos', value);
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for ContactList
mixin PartialContactListMixin on ReplaceablePartialModel<ContactList> {
  Set<String> get followingPubkeys => event.getTagSetValues('p');
  set followingPubkeys(Set<String> value) => event.setTagValues('p', value);
  void addFollowingPubkey(String? value) => event.addTagValue('p', value);
  void removeFollowingPubkey(String? value) =>
      event.removeTagWithValue('p', value);
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for DirectMessage
mixin PartialDirectMessageMixin on RegularPartialModel<DirectMessage> {
  String? get receiver => event.getFirstTagValue('p');
  set receiver(String? value) => event.setTagValue('p', value);
  String? get content => event.content.isEmpty ? null : event.content;
  set content(String? value) => event.content = value ?? '';
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for FileMetadata
mixin PartialFileMetadataMixin on RegularPartialModel<FileMetadata> {
  Set<String> get urls => event.getTagSetValues('url');
  set urls(Set<String> value) => event.setTagValues('url', value);
  void addUrl(String? value) => event.addTagValue('url', value);
  void removeUrl(String? value) => event.removeTagWithValue('url', value);
  String? get mimeType => event.getFirstTagValue('m');
  set mimeType(String? value) => event.setTagValue('m', value);
  String? get hash => event.getFirstTagValue('x');
  set hash(String? value) => event.setTagValue('x', value);
  int? get size => int.tryParse(event.getFirstTagValue('size') ?? '');
  set size(int? value) => event.setTagValue('size', value?.toString());
  String? get repository => event.getFirstTagValue('repository');
  set repository(String? value) => event.setTagValue('repository', value);
  Set<String> get platforms => event.getTagSetValues('f');
  set platforms(Set<String> value) => event.setTagValues('f', value);
  void addPlatform(String? value) => event.addTagValue('f', value);
  void removePlatform(String? value) => event.removeTagWithValue('f', value);
  Set<String> get executables => event.getTagSetValues('executable');
  set executables(Set<String> value) => event.setTagValues('executable', value);
  void addExecutable(String? value) => event.addTagValue('executable', value);
  void removeExecutable(String? value) =>
      event.removeTagWithValue('executable', value);
  String? get minSdkVersion => event.getFirstTagValue('min_sdk_version');
  set minSdkVersion(String? value) =>
      event.setTagValue('min_sdk_version', value);
  String? get targetSdkVersion => event.getFirstTagValue('target_sdk_version');
  set targetSdkVersion(String? value) =>
      event.setTagValue('target_sdk_version', value);
  String? get appIdentifier => event.content.isEmpty ? null : event.content;
  set appIdentifier(String? value) => event.content = value ?? '';
  String? get version => event.getFirstTagValue('version');
  set version(String? value) => event.setTagValue('version', value);
  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');
  set versionCode(int? value) =>
      event.setTagValue('version_code', value?.toString());
  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');
  set apkSignatureHash(String? value) =>
      event.setTagValue('apk_signature_hash', value);
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for AppCurationSet
mixin PartialAppCurationSetMixin
    on ParameterizableReplaceablePartialEvent<AppCurationSet> {
  // No event-based getters found in AppCurationSet
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for Note
mixin PartialNoteMixin on RegularPartialModel<Note> {
  String? get content => event.content.isEmpty ? null : event.content;
  set content(String? value) => event.content = value ?? '';
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for Reaction
mixin PartialReactionMixin on RegularPartialModel<Reaction> {
  // No event-based getters found in Reaction
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for Release
mixin PartialReleaseMixin on ParameterizableReplaceablePartialEvent<Release> {
  String? get releaseNotes => event.content.isEmpty ? null : event.content;
  set releaseNotes(String? value) => event.content = value ?? '';
  String? get url => event.getFirstTagValue('url');
  set url(String? value) => event.setTagValue('url', value);
  String? get channel => event.getFirstTagValue('c');
  set channel(String? value) => event.setTagValue('c', value);
  String? get appIdentifier => event.getFirstTagValue('i');
  set appIdentifier(String? value) => event.setTagValue('i', value);
  String? get version => event.getFirstTagValue('version');
  set version(String? value) => event.setTagValue('version', value);
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for Comment
mixin PartialCommentMixin on RegularPartialModel<Comment> {
  String? get content => event.content.isEmpty ? null : event.content;
  set content(String? value) => event.content = value ?? '';
  String? get externalRootUri => event.getFirstTagValue('I');
  set externalRootUri(String? value) => event.setTagValue('I', value);
  String? get externalParentUri => event.getFirstTagValue('i');
  set externalParentUri(String? value) => event.setTagValue('i', value);
  int? get rootKind => int.tryParse(event.getFirstTagValue('K') ?? '');
  set rootKind(int? value) => event.setTagValue('K', value?.toString());
  int? get parentKind => int.tryParse(event.getFirstTagValue('k') ?? '');
  set parentKind(int? value) => event.setTagValue('k', value?.toString());
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for SoftwareAsset
mixin PartialSoftwareAssetMixin on RegularPartialModel<SoftwareAsset> {
  Set<String> get urls => event.getTagSetValues('url');
  set urls(Set<String> value) => event.setTagValues('url', value);
  void addUrl(String? value) => event.addTagValue('url', value);
  void removeUrl(String? value) => event.removeTagWithValue('url', value);
  String? get mimeType => event.getFirstTagValue('m');
  set mimeType(String? value) => event.setTagValue('m', value);
  String? get hash => event.getFirstTagValue('x');
  set hash(String? value) => event.setTagValue('x', value);
  int? get size => int.tryParse(event.getFirstTagValue('size') ?? '');
  set size(int? value) => event.setTagValue('size', value?.toString());
  String? get repository => event.getFirstTagValue('repository');
  set repository(String? value) => event.setTagValue('repository', value);
  Set<String> get platforms => event.getTagSetValues('f');
  set platforms(Set<String> value) => event.setTagValues('f', value);
  void addPlatform(String? value) => event.addTagValue('f', value);
  void removePlatform(String? value) => event.removeTagWithValue('f', value);
  Set<String> get executables => event.getTagSetValues('executable');
  set executables(Set<String> value) => event.setTagValues('executable', value);
  void addExecutable(String? value) => event.addTagValue('executable', value);
  void removeExecutable(String? value) =>
      event.removeTagWithValue('executable', value);
  String? get minOSVersion => event.getFirstTagValue('min_os_version');
  set minOSVersion(String? value) => event.setTagValue('min_os_version', value);
  String? get targetOSVersion => event.getFirstTagValue('target_os_version');
  set targetOSVersion(String? value) =>
      event.setTagValue('target_os_version', value);
  String? get appIdentifier => event.getFirstTagValue('i');
  set appIdentifier(String? value) => event.setTagValue('i', value);
  String? get version => event.getFirstTagValue('version');
  set version(String? value) => event.setTagValue('version', value);
  String? get filename => event.getFirstTagValue('filename');
  set filename(String? value) => event.setTagValue('filename', value);
  String? get variant => event.getFirstTagValue('variant');
  set variant(String? value) => event.setTagValue('variant', value);
  int? get versionCode =>
      int.tryParse(event.getFirstTagValue('version_code') ?? '');
  set versionCode(int? value) =>
      event.setTagValue('version_code', value?.toString());
  String? get apkSignatureHash => event.getFirstTagValue('apk_signature_hash');
  set apkSignatureHash(String? value) =>
      event.setTagValue('apk_signature_hash', value);
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for TargetedPublication
mixin PartialTargetedPublicationMixin
    on ParameterizableReplaceablePartialEvent<TargetedPublication> {
  int? get targetedKind => int.tryParse(event.getFirstTagValue('k') ?? '');
  set targetedKind(int? value) => event.setTagValue('k', value?.toString());
  Set<String> get relayUrls => event.getTagSetValues('r');
  set relayUrls(Set<String> value) => event.setTagValues('r', value);
  void addRelayUrl(String? value) => event.addTagValue('r', value);
  void removeRelayUrl(String? value) => event.removeTagWithValue('r', value);
  Set<String> get communityPubkeys => event.getTagSetValues('p');
  set communityPubkeys(Set<String> value) => event.setTagValues('p', value);
  void addCommunityPubkey(String? value) => event.addTagValue('p', value);
  void removeCommunityPubkey(String? value) =>
      event.removeTagWithValue('p', value);
}

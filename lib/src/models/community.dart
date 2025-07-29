part of models;

/// A community event (kind 10222) representing a Nostr community or group.
///
/// Communities provide spaces for organized discussions and content sharing.
/// They can have chat messages, content moderation, and member management.
class Community extends ReplaceableModel<Community> {
  late final HasMany<ChatMessage> chatMessages;

  Community.fromMap(super.map, super.ref) : super.fromMap() {
    chatMessages = HasMany(
      ref,
      RequestFilter<ChatMessage>(
        tags: {
          '#h': {id},
        },
      ).toRequest(),
    );
  }

  /// The community name (from tag or author's name as fallback)
  String? get name => event.getFirstTagValue('name') ?? author.value?.name;

  /// Set of preferred relay URLs for this community
  Set<String> get relayUrls => event.getTagSetValues('r');

  /// Description of the community
  String? get description =>
      event.getFirstTagValue('description') ?? author.value?.about;

  /// Content moderation sections with allowed kinds and fees
  Set<CommunityContentSection> get contentSections {
    final sections = <CommunityContentSection>{};
    String? currentContent;
    Set<int> currentKinds = {};
    int? currentFeeInSats;

    for (final tag in event.tags) {
      final [key, value, ..._] = tag;

      if (key == 'content') {
        // Finalize previous section if one was being built
        if (currentContent != null) {
          sections.add(
            CommunityContentSection(
              content: currentContent,
              kinds: currentKinds,
              feeInSats: currentFeeInSats,
            ),
          );
        }
        // Start new section
        currentContent = value;
        currentKinds = {}; // Reset kinds for the new section
        currentFeeInSats = null; // Reset fee for the new section
      } else if (currentContent != null) {
        // Only process 'k' and 'fee' if we are inside a section
        if (key == 'k') {
          final kind = int.tryParse(value);
          if (kind != null) {
            currentKinds.add(kind);
          }
        } else if (key == 'fee') {
          currentFeeInSats = int.tryParse(value);
        } else {
          // Found a tag not belonging to the current section, finalize the current section
          sections.add(
            CommunityContentSection(
              content: currentContent,
              kinds: currentKinds,
              feeInSats: currentFeeInSats,
            ),
          );
          // Reset section tracking
          currentContent = null;
          currentKinds = {};
          currentFeeInSats = null;
        }
      }
    }

    // Finalize the last section if one was being built
    if (currentContent != null) {
      sections.add(
        CommunityContentSection(
          content: currentContent,
          kinds: currentKinds,
          feeInSats: currentFeeInSats,
        ),
      );
    }

    return sections.toSet();
  }

  /// Set of Blossom server URLs for file storage
  Set<String> get blossomUrls => event.getTagSetValues('blossom');

  /// Set of Cashu mint URLs for ecash payments
  Set<String> get cashuMintUrls => event.getTagSetValues('mint');

  /// Terms of service for the community
  String? get termsOfService => event.getFirstTagValue('tos');
}

/// Generated partial model mixin for Community
mixin PartialCommunityMixin on ReplaceablePartialModel<Community> {
  /// The community name
  String? get name => event.getFirstTagValue('name');

  /// Sets the community name
  set name(String? value) => event.setTagValue('name', value);

  /// Set of preferred relay URLs for this community
  Set<String> get relayUrls => event.getTagSetValues('r');

  /// Sets the preferred relay URLs
  set relayUrls(Set<String> value) => event.setTagValues('r', value);

  /// Adds a relay URL to the community's preferred relays
  void addRelayUrl(String? value) => event.addTagValue('r', value);

  /// Removes a relay URL from the community's preferred relays
  void removeRelayUrl(String? value) => event.removeTagWithValue('r', value);

  /// Description of the community
  String? get description => event.getFirstTagValue('description');

  /// Sets the community description
  set description(String? value) => event.setTagValue('description', value);

  /// Set of Blossom server URLs for file storage
  Set<String> get blossomUrls => event.getTagSetValues('blossom');

  /// Sets the Blossom server URLs
  set blossomUrls(Set<String> value) => event.setTagValues('blossom', value);

  /// Adds a Blossom server URL for file storage
  void addBlossomUrl(String? value) => event.addTagValue('blossom', value);

  /// Removes a Blossom server URL
  void removeBlossomUrl(String? value) =>
      event.removeTagWithValue('blossom', value);

  /// Set of Cashu mint URLs for ecash payments
  Set<String> get cashuMintUrls => event.getTagSetValues('mint');

  /// Sets the Cashu mint URLs
  set cashuMintUrls(Set<String> value) => event.setTagValues('mint', value);

  /// Adds a Cashu mint URL for ecash payments
  void addCashuMintUrl(String? value) => event.addTagValue('mint', value);

  /// Removes a Cashu mint URL
  void removeCashuMintUrl(String? value) =>
      event.removeTagWithValue('mint', value);

  /// Terms of service for the community
  String? get termsOfService => event.getFirstTagValue('tos');

  /// Sets the terms of service
  set termsOfService(String? value) => event.setTagValue('tos', value);
}

/// Create and sign new community events.
///
/// Example usage:
/// ```dart
/// final community = await PartialCommunity(name: 'My Community', relayUrls: {'relay1'}).signWith(signer);
/// ```
class PartialCommunity extends ReplaceablePartialModel<Community>
    with PartialCommunityMixin {
  PartialCommunity.fromMap(super.map) : super.fromMap();

  /// Creates a new community with the specified properties
  ///
  /// [name] - The community name (required)
  /// [relayUrls] - Preferred relay URLs for the community (required)
  /// [createdAt] - Optional creation timestamp
  /// [description] - Optional community description
  /// [contentSections] - Optional content moderation sections
  /// [blossomUrls] - Optional Blossom server URLs for file storage
  /// [cashuMintUrls] - Optional Cashu mint URLs for ecash payments
  /// [termsOfService] - Optional terms of service
  PartialCommunity({
    required String name,
    DateTime? createdAt,
    required Set<String> relayUrls,
    String? description,
    Set<CommunityContentSection>? contentSections,
    Set<String> blossomUrls = const {},
    Set<String> cashuMintUrls = const {},
    String? termsOfService,
  }) {
    event.addTagValue('name', name);
    if (createdAt != null) {
      event.createdAt = createdAt;
    }
    for (final relayUrl in relayUrls) {
      event.addTagValue('r', relayUrl);
    }
    event.addTagValue('description', description);
    if (contentSections != null) {
      for (final section in contentSections) {
        event.addTagValue('content', section.content);
        for (final k in section.kinds) {
          event.addTagValue('k', k.toString());
        }
        if (section.feeInSats != null) {
          event.addTag('fee', [section.feeInSats!.toString(), 'sat']);
        }
      }
    }
    for (final url in blossomUrls) {
      event.addTagValue('blossom', url);
    }
    for (final url in cashuMintUrls) {
      event.addTagValue('mint', url);
    }
    event.addTagValue('tos', termsOfService);
  }
}

class CommunityContentSection {
  final String content;
  final Set<int> kinds;
  final int? feeInSats;

  CommunityContentSection({
    required this.content,
    required this.kinds,
    this.feeInSats,
  });
}

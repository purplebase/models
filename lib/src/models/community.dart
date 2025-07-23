part of models;

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

  String? get name => event.getFirstTagValue('name') ?? author.value?.name;
  Set<String> get relayUrls => event.getTagSetValues('r');
  String? get description => event.getFirstTagValue('description');

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

  Set<String> get blossomUrls => event.getTagSetValues('blossom');
  Set<String> get cashuMintUrls => event.getTagSetValues('mint');
  String? get termsOfService => event.getFirstTagValue('tos');
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

class PartialCommunity extends ReplaceablePartialModel<Community>
    with PartialCommunityMixin {
  PartialCommunity.fromMap(super.map) : super.fromMap();

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

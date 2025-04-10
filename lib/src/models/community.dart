import 'package:models/models.dart';

class Community extends ReplaceableEvent<Community> {
  Community.fromMap(super.map, super.ref) : super.fromMap();

  String get name => internal.getFirstTagValue('name')!;
  Set<String> get relayUrls => internal.getTagSetValues('r');
  String? get description => internal.getFirstTagValue('description');
  Set<CommunityContentSection> get contentSections {
    final sections = <CommunityContentSection>{};
    String? currentContent;
    Set<int> currentKinds = {};
    int? currentFeeInSats;

    // Assuming internal.rawTags holds the List<List<String>>
    for (final tag in TagValue.serialize(internal.tags)) {
      // Changed from internal.tags
      if (tag.isEmpty) continue; // Skip empty tags

      final key = tag[0];
      final value = tag.length > 1 ? tag[1] : null;

      if (key == 'content') {
        // Finalize previous section if one was being built
        if (currentContent != null) {
          sections.add(CommunityContentSection(
            content: currentContent,
            kinds: currentKinds,
            feeInSats: currentFeeInSats,
          ));
        }
        // Start new section
        currentContent = value;
        currentKinds = {}; // Reset kinds for the new section
        currentFeeInSats = null; // Reset fee for the new section
      } else if (currentContent != null) {
        // Only process 'k' and 'fee' if we are inside a section
        if (key == 'k' && value != null) {
          final kind = int.tryParse(value);
          if (kind != null) {
            currentKinds.add(kind);
          }
        } else if (key == 'fee' && value != null) {
          currentFeeInSats = int.tryParse(value);
        } else {
          // Found a tag not belonging to the current section, finalize the current section
          sections.add(CommunityContentSection(
            content: currentContent,
            kinds: currentKinds,
            feeInSats: currentFeeInSats,
          ));
          // Reset section tracking
          currentContent = null;
          currentKinds = {};
          currentFeeInSats = null;
        }
      }
    }

    // Finalize the last section if one was being built
    if (currentContent != null) {
      sections.add(CommunityContentSection(
        content: currentContent,
        kinds: currentKinds,
        feeInSats: currentFeeInSats,
      ));
    }

    // Return an unmodifiable set (assuming CommunityContentSection implements == and hashCode correctly)
    return Set.unmodifiable(sections);
  }

  Set<String> get blossomUrls => internal.getTagSetValues('blossom');
  Set<String> get cashuMintUrls => internal.getTagSetValues('mint');
  String? get termsOfService => internal.getFirstTagValue('tos');
}

class PartialCommunity extends ReplaceablePartialEvent<Community> {
  PartialCommunity(
      {required String name,
      DateTime? createdAt,
      required Set<String> relayUrls,
      String? description,
      Set<CommunityContentSection>? contentSections,
      Set<String> blossomUrls = const {},
      Set<String> cashuMintUrls = const {},
      String? termsOfService}) {
    internal.addTagValue('name', name);
    if (createdAt != null) {
      internal.createdAt = createdAt;
    }
    for (final relayUrl in relayUrls) {
      internal.addTagValue('r', relayUrl);
    }
    internal.addTagValue('description', description);
    if (contentSections != null) {
      for (final section in contentSections) {
        internal.addTagValue('content', section.content);
        for (final k in section.kinds) {
          internal.addTagValue('k', k.toString());
        }
        if (section.feeInSats != null) {
          internal.addTag(
              'fee', TagValue([section.feeInSats!.toString(), 'sat']));
        }
      }
    }
    for (final url in blossomUrls) {
      internal.addTagValue('blossom', url);
    }
    for (final url in cashuMintUrls) {
      internal.addTagValue('mint', url);
    }
    internal.addTagValue('tos', termsOfService);
  }
}

class CommunityContentSection {
  final String content;
  final Set<int> kinds;
  final int? feeInSats;

  CommunityContentSection(
      {required this.content, required this.kinds, this.feeInSats});
}

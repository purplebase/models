part of models;

/// A list of important content you want to highlight in your profile.
///
/// Pin lists allow users to showcase their best or most important
/// posts prominently on their profile or in special feeds.
class PinList extends ReplaceableModel<PinList> {
  PinList.fromMap(super.map, super.ref) : super.fromMap();

  /// IDs of pinned content
  Set<String> get pinnedContent => event.getTagSetValues('e');

  /// Whether this user has pinned any content
  bool get hasPinnedContent => pinnedContent.isNotEmpty;
}

/// Highlight your best content with a pin list.
class PartialPinList extends ReplaceablePartialModel<PinList> {
  PartialPinList.fromMap(super.map) : super.fromMap();

  /// IDs of pinned content
  Set<String> get pinnedContent => event.getTagSetValues('e');
  set pinnedContent(Set<String> value) => event.setTagValues('e', value);
  void addPinnedContent(String? eventId) => event.addTagValue('e', eventId);
  void removePinnedContent(String? eventId) =>
      event.removeTagWithValue('e', eventId);

  PartialPinList();
}

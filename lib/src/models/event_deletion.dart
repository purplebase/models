part of models;

/// An event deletion request (kind 5) used to request deletion of events.
///
/// Event deletion requests signal to relays and clients that certain events
/// should be considered deleted by their author. Relays may choose to honor
/// these requests by removing the referenced events from their storage.
class EventDeletionRequest extends RegularModel<EventDeletionRequest> {
  /// Events referenced for deletion
  late final HasMany<Model> deletedEvents;

  /// Authors of the events being deleted (for profile deletions)
  late final HasMany<Profile> deletedProfiles;

  EventDeletionRequest.fromMap(super.map, super.ref) : super.fromMap() {
    final validEventIds = deletedEventIds
        .where((id) => id.length == 64)
        .toSet();
    deletedEvents = HasMany(
      ref,
      validEventIds.isNotEmpty ? Request.fromIds(validEventIds) : null,
    );
    final validPubkeys = deletedProfilePubkeys
        .where((pk) => pk.length == 64)
        .toSet();
    deletedProfiles = HasMany(
      ref,
      validPubkeys.isNotEmpty
          ? RequestFilter<Profile>(authors: validPubkeys).toRequest()
          : null,
    );
  }

  /// The reason for deletion
  String get reason => event.content;

  /// Set of event IDs being requested for deletion
  Set<String> get deletedEventIds => event.getTagSetValues('e');

  /// Set of profile public keys being requested for deletion
  Set<String> get deletedProfilePubkeys => event.getTagSetValues('p');

  /// Whether this deletion request targets any events
  bool get hasDeletedEvents => deletedEventIds.isNotEmpty;

  /// Whether this deletion request targets any profiles
  bool get hasDeletedProfiles => deletedProfilePubkeys.isNotEmpty;
}

/// Generated partial model mixin for EventDeletionRequest
mixin PartialEventDeletionRequestMixin
    on RegularPartialModel<EventDeletionRequest> {
  /// The reason for deletion
  String? get reason => event.content.isEmpty ? null : event.content;

  /// Sets the reason for deletion
  set reason(String? value) => event.content = value ?? '';

  /// Set of event IDs being requested for deletion
  Set<String> get deletedEventIds => event.getTagSetValues('e');

  /// Sets the event IDs being requested for deletion
  set deletedEventIds(Set<String> value) => event.setTagValues('e', value);

  /// Adds an event ID to the deletion request
  void addDeletedEventId(String? value) => event.addTagValue('e', value);

  /// Removes an event ID from the deletion request
  void removeDeletedEventId(String? value) =>
      event.removeTagWithValue('e', value);

  /// Set of profile public keys being requested for deletion
  Set<String> get deletedProfilePubkeys => event.getTagSetValues('p');

  /// Sets the profile public keys being requested for deletion
  set deletedProfilePubkeys(Set<String> value) =>
      event.setTagValues('p', value);

  /// Adds a profile public key to the deletion request
  void addDeletedProfilePubkey(String? value) => event.addTagValue('p', value);

  /// Removes a profile public key from the deletion request
  void removeDeletedProfilePubkey(String? value) =>
      event.removeTagWithValue('p', value);
}

/// Create and sign new event deletion request events.
///
/// Example usage:
/// ```dart
/// final deletion = await PartialEventDeletionRequest(
///   reason: 'Inappropriate content',
///   deletedEventIds: {'event_id_1', 'event_id_2'},
/// ).signWith(signer);
/// ```
class PartialEventDeletionRequest
    extends RegularPartialModel<EventDeletionRequest>
    with PartialEventDeletionRequestMixin {
  PartialEventDeletionRequest.fromMap(super.map) : super.fromMap();

  /// Creates a new event deletion request
  ///
  /// [reason] - The reason for deletion (optional)
  /// [deletedEventIds] - Set of event IDs to delete (optional)
  /// [deletedProfilePubkeys] - Set of profile public keys to delete (optional)
  PartialEventDeletionRequest({
    String? reason,
    Set<String>? deletedEventIds,
    Set<String>? deletedProfilePubkeys,
  }) {
    if (reason != null) this.reason = reason;
    if (deletedEventIds != null) this.deletedEventIds = deletedEventIds;
    if (deletedProfilePubkeys != null) {
      this.deletedProfilePubkeys = deletedProfilePubkeys;
    }
  }
}

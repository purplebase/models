part of models;

/// PollResponse represents a poll vote/response event (kind 1018) as specified in NIP-88.
/// It contains the user's selected option(s) for a poll.
class PollResponse extends RegularModel<PollResponse> {
  late final BelongsTo<Poll> poll;

  PollResponse.fromMap(super.map, super.ref) : super.fromMap() {
    // Reference to the poll being responded to
    poll = BelongsTo(
      ref,
      event.containsTag('e')
          ? RequestFilter<Poll>(
              ids: {event.getFirstTagValue('e')!},
              kinds: {1068},
            ).toRequest()
          : null,
    );
  }

  /// The poll event ID this response is for
  String? get pollId => event.getFirstTagValue('e');

  /// Selected option IDs from response tags
  ///
  /// For singlechoice polls, only the first response is considered valid.
  /// For multiplechoice polls, all unique response IDs are valid.
  Set<String> get selectedOptionIds {
    final responseTags = event.getTagSet('response');
    return responseTags
        .where((tag) => tag.length >= 2)
        .map((tag) => tag[1]) // tag is ["response", "option_id"]
        .toSet();
  }

  /// Get the first selected option (for singlechoice polls)
  String? get selectedOptionId {
    final responses = selectedOptionIds;
    return responses.isEmpty ? null : responses.first;
  }

  /// The content field (usually empty for poll responses)
  String get content => event.content;
}

/// Mixin for PartialPollResponse providing getters/setters
mixin PartialPollResponseMixin on RegularPartialModel<PollResponse> {
  String? get pollId => event.getFirstTagValue('e');

  Set<String> get selectedOptionIds {
    final responseTags = event.getTagSet('response');
    return responseTags
        .where((tag) => tag.length >= 2)
        .map((tag) => tag[1]) // tag is ["response", "option_id"]
        .toSet();
  }

  /// Add a response (vote) for an option
  void addResponse(String optionId) {
    event.addTag('response', [optionId]);
  }

  /// Remove a response for an option
  void removeResponse(String optionId) {
    event.removeTagWithValue('response', optionId);
  }

  /// Clear all responses
  void clearResponses() {
    for (final optionId in selectedOptionIds) {
      event.removeTagWithValue('response', optionId);
    }
  }
}

/// Create and sign new poll response events.
///
/// Example usage:
/// ```dart
/// // Single choice vote
/// final vote = await PartialPollResponse(
///   poll: pollEvent,
///   selectedOptionIds: {'option_a'},
/// ).signWith(signer);
///
/// // Multiple choice vote
/// final multiVote = await PartialPollResponse(
///   poll: pollEvent,
///   selectedOptionIds: {'option_a', 'option_c'},
/// ).signWith(signer);
/// ```
class PartialPollResponse extends RegularPartialModel<PollResponse>
    with PartialPollResponseMixin {
  PartialPollResponse.fromMap(super.map) : super.fromMap();

  /// Creates a new poll response (vote)
  ///
  /// [poll] - The poll being voted on (required)
  /// [selectedOptionIds] - Set of selected option IDs (required)
  /// [createdAt] - Optional creation timestamp
  PartialPollResponse({
    required Poll poll,
    required Set<String> selectedOptionIds,
    DateTime? createdAt,
  }) {
    // Content is empty for poll responses per NIP-88
    event.content = '';

    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    // Reference the poll event
    event.addTag('e', [poll.event.id]);

    // Add response tags for each selected option
    for (final optionId in selectedOptionIds) {
      event.addTag('response', [optionId]);
    }
  }

  /// Creates a poll response by poll ID (when you don't have the full Poll model)
  PartialPollResponse.byPollId({
    required String pollId,
    required Set<String> selectedOptionIds,
    DateTime? createdAt,
  }) {
    event.content = '';

    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    // Reference the poll event by ID
    event.addTag('e', [pollId]);

    // Add response tags
    for (final optionId in selectedOptionIds) {
      event.addTag('response', [optionId]);
    }
  }
}

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

  /// Selected option IDs from response tags (preserves tag order)
  ///
  /// Returns a List to preserve the order of response tags in the event.
  /// For singlechoice polls, only the first response is considered valid (use [firstSelectedOptionId]).
  /// For multiplechoice polls, all responses are valid.
  List<String> get selectedOptionIds {
    // Use tags directly to preserve order (getTagSet returns Set which loses order)
    return event.tags
        .where((tag) => tag[0] == 'response' && tag.length >= 2)
        .map((tag) => tag[1]) // tag is ["response", "option_id"]
        .toList();
  }

  /// Get the first selected option (for singlechoice polls per NIP-88)
  ///
  /// NIP-88 specifies that for singlechoice polls, only the first response tag counts.
  String? get firstSelectedOptionId {
    final responses = selectedOptionIds;
    return responses.isEmpty ? null : responses.first;
  }

  /// The content field (usually empty for poll responses)
  String get content => event.content;
}

/// Mixin for PartialPollResponse providing getters/setters
mixin PartialPollResponseMixin on RegularPartialModel<PollResponse> {
  String? get pollId => event.getFirstTagValue('e');

  /// Selected option IDs (preserves tag order)
  List<String> get selectedOptionIds {
    return event.tags
        .where((tag) => tag[0] == 'response' && tag.length >= 2)
        .map((tag) => tag[1])
        .toList();
  }

  /// First selected option (for singlechoice polls per NIP-88)
  String? get firstSelectedOptionId {
    final responses = selectedOptionIds;
    return responses.isEmpty ? null : responses.first;
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
/// // Single choice vote (only first option counts per NIP-88)
/// final vote = await PartialPollResponse(
///   poll: pollEvent,
///   selectedOptionIds: ['option_a'],
/// ).signWith(signer);
///
/// // Multiple choice vote
/// final multiVote = await PartialPollResponse(
///   poll: pollEvent,
///   selectedOptionIds: ['option_a', 'option_c'],
/// ).signWith(signer);
/// ```
class PartialPollResponse extends RegularPartialModel<PollResponse>
    with PartialPollResponseMixin {
  PartialPollResponse.fromMap(super.map) : super.fromMap();

  /// Creates a new poll response (vote)
  ///
  /// [poll] - The poll being voted on (required)
  /// [selectedOptionIds] - List of selected option IDs (order matters for singlechoice)
  /// [createdAt] - Optional creation timestamp
  ///
  /// Note: For singlechoice polls, only the first option ID will be counted per NIP-88.
  PartialPollResponse({
    required Poll poll,
    required Iterable<String> selectedOptionIds,
    DateTime? createdAt,
  }) {
    // Content is empty for poll responses per NIP-88
    event.content = '';

    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    // Reference the poll event
    event.addTag('e', [poll.event.id]);

    // Add response tags for each selected option (order preserved)
    for (final optionId in selectedOptionIds) {
      event.addTag('response', [optionId]);
    }
  }

  /// Creates a poll response by poll ID (when you don't have the full Poll model)
  PartialPollResponse.byPollId({
    required String pollId,
    required Iterable<String> selectedOptionIds,
    DateTime? createdAt,
  }) {
    event.content = '';

    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    // Reference the poll event by ID
    event.addTag('e', [pollId]);

    // Add response tags (order preserved)
    for (final optionId in selectedOptionIds) {
      event.addTag('response', [optionId]);
    }
  }
}

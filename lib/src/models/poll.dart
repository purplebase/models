part of models;

/// Poll option with ID and label
class PollOption extends Equatable {
  final String id;
  final String label;

  const PollOption({required this.id, required this.label});

  @override
  List<Object?> get props => [id, label];
}

/// Poll types as defined in NIP-88
enum PollType {
  singlechoice,
  multiplechoice;

  static PollType fromString(String? value) {
    if (value == 'multiplechoice') return PollType.multiplechoice;
    return PollType.singlechoice; // Default per NIP-88
  }
}

/// Poll represents a poll event (kind 1068) as specified in NIP-88.
/// Polls allow users to create questions with multiple choice options.
class Poll extends RegularModel<Poll> {
  late final BelongsTo<Profile> author;
  late final HasMany<PollResponse> responses;
  late final BelongsTo<Model> targetModel;

  Poll.fromMap(super.map, super.ref) : super.fromMap() {
    // Author relationship (inherited from Model but we set it up here for clarity)
    author = BelongsTo(
      ref,
      RequestFilter<Profile>(authors: {event.pubkey}).toRequest(),
    );

    // All responses to this poll
    responses = HasMany(
      ref,
      RequestFilter<PollResponse>(
        tags: {
          '#e': {event.id},
        },
        kinds: {1018},
      ).toRequest(),
    );

    // Target model (what this poll is about - e.g., an App)
    if (event.containsTag('a')) {
      targetModel = BelongsTo(
        ref,
        Request.fromIds({event.getFirstTagValue('a')!}),
      );
    } else if (event.containsTag('A')) {
      targetModel = BelongsTo(
        ref,
        Request.fromIds({event.getFirstTagValue('A')!}),
      );
    } else {
      targetModel = BelongsTo(ref, null);
    }
  }

  /// The poll question/label
  String get content => event.content;

  /// Poll options extracted from option tags
  List<PollOption> get options {
    final optionTags = event.getTagValues('option');
    return optionTags.map((values) {
      if (values.length >= 2) {
        return PollOption(id: values[0], label: values[1]);
      }
      return null;
    }).whereType<PollOption>().toList();
  }

  /// Poll type (singlechoice or multiplechoice)
  PollType get pollType =>
      PollType.fromString(event.getFirstTagValue('polltype'));

  /// When the poll ends (optional)
  DateTime? get endsAt {
    final timestamp = event.getFirstTagValue('endsAt');
    if (timestamp == null) return null;
    final seconds = int.tryParse(timestamp);
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  /// Whether the poll has expired
  bool get isExpired {
    final end = endsAt;
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  /// Suggested relays for responses
  Set<String> get relays => event.getTagSetValues('relay');
}

/// Mixin for PartialPoll providing getters/setters
mixin PartialPollMixin on RegularPartialModel<Poll> {
  String? get content => event.content.isEmpty ? null : event.content;
  set content(String? value) => event.content = value ?? '';

  List<PollOption> get options {
    final optionTags = event.getTagValues('option');
    return optionTags.map((values) {
      if (values.length >= 2) {
        return PollOption(id: values[0], label: values[1]);
      }
      return null;
    }).whereType<PollOption>().toList();
  }

  void addOption(PollOption option) {
    event.addTag('option', [option.id, option.label]);
  }

  void removeOption(String optionId) {
    event.removeTagWithValue('option', optionId);
  }

  PollType get pollType =>
      PollType.fromString(event.getFirstTagValue('polltype'));

  set pollType(PollType value) =>
      event.setTagValue('polltype', value.name);

  DateTime? get endsAt {
    final timestamp = event.getFirstTagValue('endsAt');
    if (timestamp == null) return null;
    final seconds = int.tryParse(timestamp);
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  set endsAt(DateTime? value) {
    if (value == null) {
      event.removeTagWithValue('endsAt', event.getFirstTagValue('endsAt') ?? '');
    } else {
      event.setTagValue(
        'endsAt',
        (value.millisecondsSinceEpoch ~/ 1000).toString(),
      );
    }
  }

  void addRelay(String relayUrl) {
    event.addTag('relay', [relayUrl]);
  }
}

/// Create and sign new poll events.
///
/// Example usage:
/// ```dart
/// final poll = await PartialPoll(
///   content: 'Which feature should we build next?',
///   options: [
///     PollOption(id: 'a', label: 'Dark mode'),
///     PollOption(id: 'b', label: 'Offline support'),
///     PollOption(id: 'c', label: 'Push notifications'),
///   ],
///   pollType: PollType.singlechoice,
///   endsAt: DateTime.now().add(Duration(days: 7)),
///   targetModel: app,
/// ).signWith(signer);
/// ```
class PartialPoll extends RegularPartialModel<Poll> with PartialPollMixin {
  PartialPoll.fromMap(super.map) : super.fromMap();

  /// Creates a new poll
  ///
  /// [content] - The poll question (required)
  /// [options] - List of poll options (required, at least 2)
  /// [pollType] - Single or multiple choice (default: singlechoice)
  /// [endsAt] - When the poll expires (optional)
  /// [targetModel] - The model this poll is about (e.g., an App)
  /// [relays] - Suggested relays for responses
  /// [createdAt] - Optional creation timestamp
  PartialPoll({
    required String content,
    required List<PollOption> options,
    PollType pollType = PollType.singlechoice,
    DateTime? endsAt,
    Model? targetModel,
    Set<String>? relays,
    DateTime? createdAt,
  }) {
    event.content = content;

    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    // Add options
    for (final option in options) {
      event.addTag('option', [option.id, option.label]);
    }

    // Set poll type
    event.setTagValue('polltype', pollType.name);

    // Set end time if provided
    if (endsAt != null) {
      event.setTagValue(
        'endsAt',
        (endsAt.millisecondsSinceEpoch ~/ 1000).toString(),
      );
    }

    // Link to target model if provided
    if (targetModel != null) {
      linkModel(targetModel);
    }

    // Add relay hints
    if (relays != null) {
      for (final relay in relays) {
        event.addTag('relay', [relay]);
      }
    }
  }
}

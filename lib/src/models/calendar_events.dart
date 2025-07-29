part of models;

/// A date-based calendar event that spans entire days.
///
/// Date-based events are perfect for holidays, birthdays, vacations, or any
/// all-day events where specific times don't matter. They use simple dates
/// without time zones or hour precision.
class DateBasedCalendarEvent
    extends ParameterizableReplaceableModel<DateBasedCalendarEvent> {
  /// Event participants
  late final HasMany<Profile> participants;

  /// Comments on this calendar event
  late final HasMany<Comment> comments;

  /// RSVPs for this calendar event
  late final HasMany<CalendarEventRSVP> rsvps;

  DateBasedCalendarEvent.fromMap(super.map, super.ref) : super.fromMap() {
    participants = HasMany(
      ref,
      participantPubkeys.isNotEmpty
          ? RequestFilter<Profile>(authors: participantPubkeys).toRequest()
          : null,
    );

    comments = HasMany(
      ref,
      RequestFilter<Comment>(
        tags: {
          '#a': {event.addressableId},
        },
      ).toRequest(),
    );

    rsvps = HasMany(
      ref,
      RequestFilter<CalendarEventRSVP>(
        tags: {
          '#a': {event.addressableId},
        },
      ).toRequest(),
    );
  }

  /// The event title or name
  String? get title => event.getFirstTagValue('title');

  /// The event description
  String get description => event.content;

  /// Start date in YYYY-MM-DD format
  String? get startDate => event.getFirstTagValue('start');

  /// End date in YYYY-MM-DD format (exclusive)
  String? get endDate => event.getFirstTagValue('end');

  /// Parsed start date as DateTime (at midnight)
  DateTime? get startDateTime {
    final date = startDate;
    return date != null ? DateTime.tryParse('${date}T00:00:00Z') : null;
  }

  /// Parsed end date as DateTime (at midnight)
  DateTime? get endDateTime {
    final date = endDate;
    return date != null ? DateTime.tryParse('${date}T00:00:00Z') : null;
  }

  /// Event location or venue
  String? get location => event.getFirstTagValue('location');

  /// Geographic hash for location-based searches
  String? get geohash => event.getFirstTagValue('g');

  /// Brief summary of the event
  String? get summary => event.getFirstTagValue('summary');

  /// Image URL for the event
  String? get imageUrl => event.getFirstTagValue('image');

  /// Hashtags for categorizing the event
  Set<String> get hashtags => event.getTagSetValues('t');

  /// Reference URLs related to the event
  Set<String> get referenceUrls => event.getTagSetValues('r');

  /// Public keys of event participants
  Set<String> get participantPubkeys => event.getTagSetValues('p');

  /// Whether this is a single-day event
  bool get isSingleDay => endDate == null || startDate == endDate;

  /// Whether this event has location information
  bool get hasLocation => location != null || geohash != null;

  /// Duration in days (1 for single day events)
  int get durationInDays {
    if (isSingleDay) return 1;
    final start = startDateTime;
    final end = endDateTime;
    if (start != null && end != null) {
      return end.difference(start).inDays;
    }
    return 1;
  }
}

/// A time-based calendar event with specific start and end times.
///
/// Time-based events are ideal for meetings, appointments, concerts, or any
/// event where precise timing matters. They support time zones and can
/// span any duration from minutes to days.
class TimeBasedCalendarEvent
    extends ParameterizableReplaceableModel<TimeBasedCalendarEvent> {
  /// Event participants
  late final HasMany<Profile> participants;

  /// Related calendar that contains this event
  late final BelongsTo<Calendar> calendar;

  /// Comments on this calendar event
  late final HasMany<Comment> comments;

  /// RSVPs for this calendar event
  late final HasMany<CalendarEventRSVP> rsvps;

  TimeBasedCalendarEvent.fromMap(super.map, super.ref) : super.fromMap() {
    participants = HasMany(
      ref,
      participantPubkeys.isNotEmpty
          ? RequestFilter<Profile>(authors: participantPubkeys).toRequest()
          : null,
    );

    calendar = BelongsTo(
      ref,
      null, // Calendars reference events, not the other way around
    );

    comments = HasMany(
      ref,
      RequestFilter<Comment>(
        tags: {
          '#a': {event.addressableId},
        },
      ).toRequest(),
    );

    rsvps = HasMany(
      ref,
      RequestFilter<CalendarEventRSVP>(
        tags: {
          '#a': {event.addressableId},
        },
      ).toRequest(),
    );
  }

  /// The event title or name
  String? get title => event.getFirstTagValue('title');

  /// The event description
  String get description => event.content;

  /// Start time as Unix timestamp in seconds
  int? get startTimestamp {
    final start = event.getFirstTagValue('start');
    return start != null ? int.tryParse(start) : null;
  }

  /// End time as Unix timestamp in seconds
  int? get endTimestamp {
    final end = event.getFirstTagValue('end');
    return end != null ? int.tryParse(end) : null;
  }

  /// Start time as DateTime
  DateTime? get startDateTime {
    final timestamp = startTimestamp;
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
        : null;
  }

  /// End time as DateTime
  DateTime? get endDateTime {
    final timestamp = endTimestamp;
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
        : null;
  }

  /// Time zone for the start time
  String? get startTimeZone => event.getFirstTagValue('start_tzid');

  /// Time zone for the end time
  String? get endTimeZone => event.getFirstTagValue('end_tzid');

  /// Event location or venue
  String? get location => event.getFirstTagValue('location');

  /// Geographic hash for location-based searches
  String? get geohash => event.getFirstTagValue('g');

  /// Brief summary of the event
  String? get summary => event.getFirstTagValue('summary');

  /// Image URL for the event
  String? get imageUrl => event.getFirstTagValue('image');

  /// Hashtags for categorizing the event
  Set<String> get hashtags => event.getTagSetValues('t');

  /// Reference URLs related to the event
  Set<String> get referenceUrls => event.getTagSetValues('r');

  /// Public keys of event participants
  Set<String> get participantPubkeys => event.getTagSetValues('p');

  /// Whether this event happens instantly (no end time)
  bool get isInstantaneous => endTimestamp == null;

  /// Whether this event has location information
  bool get hasLocation => location != null || geohash != null;

  /// Duration in minutes
  int? get durationInMinutes {
    final start = startTimestamp;
    final end = endTimestamp;
    if (start != null && end != null) {
      return ((end - start) / 60).round();
    }
    return null;
  }
}

/// A collection of calendar events organized together.
///
/// Calendars help users organize their events into logical groups like
/// "Personal", "Work", "Travel", or "Community Events" for better management
/// and different sharing permissions.
class Calendar extends ParameterizableReplaceableModel<Calendar> {
  /// Events contained in this calendar
  late final HasMany<Model> events;

  Calendar.fromMap(super.map, super.ref) : super.fromMap() {
    events = HasMany(
      ref,
      eventAddresses.isNotEmpty ? Request.fromIds(eventAddresses) : null,
    );
  }

  /// The calendar title
  String? get title => event.getFirstTagValue('title');

  /// The calendar description
  String get description => event.content;

  /// Addresses of events in this calendar
  Set<String> get eventAddresses => event.getTagSetValues('a');

  /// Whether this calendar contains any events
  bool get hasEvents => eventAddresses.isNotEmpty;

  /// Number of events in this calendar
  int get eventCount => eventAddresses.length;
}

/// A response to a calendar event indicating attendance intention.
///
/// RSVPs help event organizers plan for attendance and give participants
/// a way to communicate their plans. They can be updated as plans change
/// and include optional notes for context.
class CalendarEventRSVP
    extends ParameterizableReplaceableModel<CalendarEventRSVP> {
  /// The calendar event being responded to
  late final BelongsTo<Model> calendarEvent;

  /// The event's original author
  late final BelongsTo<Profile> eventAuthor;

  CalendarEventRSVP.fromMap(super.map, super.ref) : super.fromMap() {
    calendarEvent = BelongsTo(
      ref,
      eventAddress != null
          ? Request.fromIds({eventAddress!})
          : eventId != null
          ? Request.fromIds({eventId!})
          : null,
    );

    eventAuthor = BelongsTo(
      ref,
      eventAuthorPubkey != null
          ? RequestFilter<Profile>(authors: {eventAuthorPubkey!}).toRequest()
          : null,
    );
  }

  /// Optional note or message with the RSVP
  String get note => event.content;

  /// The event address being responded to
  String? get eventAddress => event.getFirstTagValue('a');

  /// The event ID being responded to (alternative to address)
  String? get eventId => event.getFirstTagValue('e');

  /// Public key of the event author
  String? get eventAuthorPubkey => event.getFirstTagValue('p');

  /// RSVP status response
  RSVPStatus? get status {
    final statusStr = event.getFirstTagValue('status');
    return statusStr != null ? RSVPStatus.fromString(statusStr) : null;
  }

  /// Availability status during the event
  AvailabilityStatus? get availability {
    final fbStr = event.getFirstTagValue('fb');
    return fbStr != null ? AvailabilityStatus.fromString(fbStr) : null;
  }

  /// Whether this is a positive response
  bool get isAccepted => status == RSVPStatus.accepted;

  /// Whether this is a negative response
  bool get isDeclined => status == RSVPStatus.declined;

  /// Whether this is a tentative response
  bool get isTentative => status == RSVPStatus.tentative;
}

/// Possible responses to calendar event invitations
enum RSVPStatus {
  /// Will definitely attend
  accepted,

  /// Will not attend
  declined,

  /// Might attend, not certain
  tentative;

  /// Creates status from string value
  static RSVPStatus? fromString(String value) {
    switch (value.toLowerCase()) {
      case 'accepted':
        return RSVPStatus.accepted;
      case 'declined':
        return RSVPStatus.declined;
      case 'tentative':
        return RSVPStatus.tentative;
      default:
        return null;
    }
  }

  /// Protocol string representation
  String get protocolValue {
    switch (this) {
      case RSVPStatus.accepted:
        return 'accepted';
      case RSVPStatus.declined:
        return 'declined';
      case RSVPStatus.tentative:
        return 'tentative';
    }
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case RSVPStatus.accepted:
        return 'Attending';
      case RSVPStatus.declined:
        return 'Not Attending';
      case RSVPStatus.tentative:
        return 'Maybe';
    }
  }
}

/// User availability during calendar events
enum AvailabilityStatus {
  /// Available during the event time
  free,

  /// Not available during the event time
  busy;

  /// Creates availability from string value
  static AvailabilityStatus? fromString(String value) {
    switch (value.toLowerCase()) {
      case 'free':
        return AvailabilityStatus.free;
      case 'busy':
        return AvailabilityStatus.busy;
      default:
        return null;
    }
  }

  /// Protocol string representation
  String get protocolValue {
    switch (this) {
      case AvailabilityStatus.free:
        return 'free';
      case AvailabilityStatus.busy:
        return 'busy';
    }
  }
}

/// Create date-based calendar events for holidays, birthdays, and all-day occasions.
///
/// Example usage:
/// ```dart
/// final vacation = await PartialDateBasedCalendarEvent(
///   title: 'Summer Vacation',
///   startDate: '2024-07-15',
///   endDate: '2024-07-22',
///   location: 'Beach Resort',
///   description: 'Family vacation by the ocean',
/// ).signWith(signer);
/// ```
class PartialDateBasedCalendarEvent
    extends ParameterizableReplaceablePartialModel<DateBasedCalendarEvent> {
  PartialDateBasedCalendarEvent.fromMap(super.map) : super.fromMap();

  /// The event title or name
  String? get title => event.getFirstTagValue('title');
  set title(String? value) => event.setTagValue('title', value);

  /// The event description
  String? get description => event.content.isEmpty ? null : event.content;
  set description(String? value) => event.content = value ?? '';

  /// Start date in YYYY-MM-DD format
  String? get startDate => event.getFirstTagValue('start');
  set startDate(String? value) => event.setTagValue('start', value);

  /// End date in YYYY-MM-DD format (exclusive)
  String? get endDate => event.getFirstTagValue('end');
  set endDate(String? value) => event.setTagValue('end', value);

  /// Event location or venue
  String? get location => event.getFirstTagValue('location');
  set location(String? value) => event.setTagValue('location', value);

  /// Geographic hash for location-based searches
  String? get geohash => event.getFirstTagValue('g');
  set geohash(String? value) => event.setTagValue('g', value);

  /// Brief summary of the event
  String? get summary => event.getFirstTagValue('summary');
  set summary(String? value) => event.setTagValue('summary', value);

  /// Image URL for the event
  String? get imageUrl => event.getFirstTagValue('image');
  set imageUrl(String? value) => event.setTagValue('image', value);

  /// Hashtags for categorizing the event
  Set<String> get hashtags => event.getTagSetValues('t');
  set hashtags(Set<String> value) => event.setTagValues('t', value);
  void addHashtag(String? hashtag) => event.addTagValue('t', hashtag);
  void removeHashtag(String? hashtag) => event.removeTagWithValue('t', hashtag);

  /// Reference URLs related to the event
  Set<String> get referenceUrls => event.getTagSetValues('r');
  set referenceUrls(Set<String> value) => event.setTagValues('r', value);
  void addReferenceUrl(String? url) => event.addTagValue('r', url);
  void removeReferenceUrl(String? url) => event.removeTagWithValue('r', url);

  /// Public keys of event participants
  Set<String> get participantPubkeys => event.getTagSetValues('p');
  set participantPubkeys(Set<String> value) => event.setTagValues('p', value);
  void addParticipant(String? pubkey) => event.addTagValue('p', pubkey);
  void removeParticipant(String? pubkey) =>
      event.removeTagWithValue('p', pubkey);

  /// Creates a date-based calendar event
  ///
  /// [title] - The event title (required)
  /// [startDate] - Start date in YYYY-MM-DD format (required)
  /// [description] - Event description (optional)
  /// [endDate] - End date in YYYY-MM-DD format (optional, defaults to same day)
  /// [location] - Event location (optional)
  /// [identifier] - Unique identifier (auto-generated if not provided)
  PartialDateBasedCalendarEvent({
    required String title,
    required String startDate,
    String? description,
    String? endDate,
    String? location,
    String? identifier,
    String? summary,
    String? imageUrl,
    Set<String>? hashtags,
    Set<String>? participants,
  }) {
    this.title = title;
    this.startDate = startDate;
    if (description != null) this.description = description;
    if (endDate != null) this.endDate = endDate;
    if (location != null) this.location = location;
    if (summary != null) this.summary = summary;
    if (imageUrl != null) this.imageUrl = imageUrl;
    if (hashtags != null) this.hashtags = hashtags;
    if (participants != null) participantPubkeys = participants;
    event.setTagValue('d', identifier ?? _generateIdentifier());
  }

  String _generateIdentifier() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}

/// Create time-based calendar events for meetings, appointments, and scheduled activities.
class PartialTimeBasedCalendarEvent
    extends ParameterizableReplaceablePartialModel<TimeBasedCalendarEvent> {
  PartialTimeBasedCalendarEvent.fromMap(super.map) : super.fromMap();

  /// The event title or name
  String? get title => event.getFirstTagValue('title');
  set title(String? value) => event.setTagValue('title', value);

  /// The event description
  String? get description => event.content.isEmpty ? null : event.content;
  set description(String? value) => event.content = value ?? '';

  /// Start time as Unix timestamp in seconds
  int? get startTimestamp {
    final start = event.getFirstTagValue('start');
    return start != null ? int.tryParse(start) : null;
  }

  set startTimestamp(int? value) =>
      event.setTagValue('start', value?.toString());

  /// End time as Unix timestamp in seconds
  int? get endTimestamp {
    final end = event.getFirstTagValue('end');
    return end != null ? int.tryParse(end) : null;
  }

  set endTimestamp(int? value) => event.setTagValue('end', value?.toString());

  /// Time zone for the start time
  String? get startTimeZone => event.getFirstTagValue('start_tzid');
  set startTimeZone(String? value) => event.setTagValue('start_tzid', value);

  /// Time zone for the end time
  String? get endTimeZone => event.getFirstTagValue('end_tzid');
  set endTimeZone(String? value) => event.setTagValue('end_tzid', value);

  /// Event location or venue
  String? get location => event.getFirstTagValue('location');
  set location(String? value) => event.setTagValue('location', value);

  /// Geographic hash for location-based searches
  String? get geohash => event.getFirstTagValue('g');
  set geohash(String? value) => event.setTagValue('g', value);

  /// Brief summary of the event
  String? get summary => event.getFirstTagValue('summary');
  set summary(String? value) => event.setTagValue('summary', value);

  /// Image URL for the event
  String? get imageUrl => event.getFirstTagValue('image');
  set imageUrl(String? value) => event.setTagValue('image', value);

  /// Hashtags for categorizing the event
  Set<String> get hashtags => event.getTagSetValues('t');
  set hashtags(Set<String> value) => event.setTagValues('t', value);
  void addHashtag(String? hashtag) => event.addTagValue('t', hashtag);
  void removeHashtag(String? hashtag) => event.removeTagWithValue('t', hashtag);

  /// Reference URLs related to the event
  Set<String> get referenceUrls => event.getTagSetValues('r');
  set referenceUrls(Set<String> value) => event.setTagValues('r', value);
  void addReferenceUrl(String? url) => event.addTagValue('r', url);
  void removeReferenceUrl(String? url) => event.removeTagWithValue('r', url);

  /// Public keys of event participants
  Set<String> get participantPubkeys => event.getTagSetValues('p');
  set participantPubkeys(Set<String> value) => event.setTagValues('p', value);
  void addParticipant(String? pubkey) => event.addTagValue('p', pubkey);
  void removeParticipant(String? pubkey) =>
      event.removeTagWithValue('p', pubkey);

  /// Sets start time from DateTime
  void setStartDateTime(DateTime dateTime, {String? timeZone}) {
    startTimestamp = (dateTime.millisecondsSinceEpoch / 1000).round();
    if (timeZone != null) startTimeZone = timeZone;
  }

  /// Sets end time from DateTime
  void setEndDateTime(DateTime dateTime, {String? timeZone}) {
    endTimestamp = (dateTime.millisecondsSinceEpoch / 1000).round();
    if (timeZone != null) endTimeZone = timeZone;
  }

  /// Creates a time-based calendar event
  ///
  /// [title] - The event title (required)
  /// [startTime] - Start time (required)
  /// [description] - Event description (optional)
  /// [endTime] - End time (optional)
  /// [location] - Event location (optional)
  /// [identifier] - Unique identifier (auto-generated if not provided)
  PartialTimeBasedCalendarEvent({
    required String title,
    required DateTime startTime,
    String? description,
    DateTime? endTime,
    String? location,
    String? startTimeZone,
    String? endTimeZone,
    String? identifier,
    String? summary,
    String? imageUrl,
    Set<String>? hashtags,
    Set<String>? participants,
  }) {
    this.title = title;
    setStartDateTime(startTime, timeZone: startTimeZone);
    if (description != null) this.description = description;
    if (endTime != null) setEndDateTime(endTime, timeZone: endTimeZone);
    if (location != null) this.location = location;
    if (summary != null) this.summary = summary;
    if (imageUrl != null) this.imageUrl = imageUrl;
    if (hashtags != null) this.hashtags = hashtags;
    if (participants != null) participantPubkeys = participants;
    event.setTagValue('d', identifier ?? _generateIdentifier());
  }

  String _generateIdentifier() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}

/// Organize your calendar events into logical collections.
class PartialCalendar extends ParameterizableReplaceablePartialModel<Calendar> {
  PartialCalendar.fromMap(super.map) : super.fromMap();

  /// The calendar title
  String? get title => event.getFirstTagValue('title');
  set title(String? value) => event.setTagValue('title', value);

  /// The calendar description
  String? get description => event.content.isEmpty ? null : event.content;
  set description(String? value) => event.content = value ?? '';

  /// Addresses of events in this calendar
  Set<String> get eventAddresses => event.getTagSetValues('a');
  set eventAddresses(Set<String> value) => event.setTagValues('a', value);
  void addEventAddress(String? address) => event.addTagValue('a', address);
  void removeEventAddress(String? address) =>
      event.removeTagWithValue('a', address);

  /// Creates a new calendar
  PartialCalendar({
    required String title,
    String? description,
    String? identifier,
    Set<String>? eventAddresses,
  }) {
    this.title = title;
    if (description != null) this.description = description;
    if (eventAddresses != null) this.eventAddresses = eventAddresses;
    event.setTagValue('d', identifier ?? _generateIdentifier());
  }

  String _generateIdentifier() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}

/// Respond to calendar event invitations.
class PartialCalendarEventRSVP
    extends ParameterizableReplaceablePartialModel<CalendarEventRSVP> {
  PartialCalendarEventRSVP.fromMap(super.map) : super.fromMap();

  /// Optional note or message with the RSVP
  String? get note => event.content.isEmpty ? null : event.content;
  set note(String? value) => event.content = value ?? '';

  /// The event address being responded to
  String? get eventAddress => event.getFirstTagValue('a');
  set eventAddress(String? value) => event.setTagValue('a', value);

  /// The event ID being responded to (alternative to address)
  String? get eventId => event.getFirstTagValue('e');
  set eventId(String? value) => event.setTagValue('e', value);

  /// Public key of the event author
  String? get eventAuthorPubkey => event.getFirstTagValue('p');
  set eventAuthorPubkey(String? value) => event.setTagValue('p', value);

  /// RSVP status response
  RSVPStatus? get status {
    final statusStr = event.getFirstTagValue('status');
    return statusStr != null ? RSVPStatus.fromString(statusStr) : null;
  }

  set status(RSVPStatus? value) =>
      event.setTagValue('status', value?.protocolValue);

  /// Availability status during the event
  AvailabilityStatus? get availability {
    final fbStr = event.getFirstTagValue('fb');
    return fbStr != null ? AvailabilityStatus.fromString(fbStr) : null;
  }

  set availability(AvailabilityStatus? value) =>
      event.setTagValue('fb', value?.protocolValue);

  /// Creates an RSVP response to a calendar event
  ///
  /// [eventAddress] - Address of the calendar event (required)
  /// [status] - RSVP response status (required)
  /// [note] - Optional message with the response
  /// [availability] - Whether you're free or busy during the event
  /// [eventAuthorPubkey] - Public key of the event creator
  PartialCalendarEventRSVP({
    required String eventAddress,
    required RSVPStatus status,
    String? note,
    AvailabilityStatus? availability,
    String? eventAuthorPubkey,
    String? identifier,
  }) {
    this.eventAddress = eventAddress;
    this.status = status;
    if (note != null) this.note = note;
    if (availability != null) this.availability = availability;
    if (eventAuthorPubkey != null) this.eventAuthorPubkey = eventAuthorPubkey;
    event.setTagValue('d', identifier ?? _generateIdentifier());
  }

  String _generateIdentifier() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}

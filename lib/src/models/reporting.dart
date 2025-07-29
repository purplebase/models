part of models;

/// A content report used to flag objectionable material for moderation.
///
/// Reports help communities and platforms identify content that violates
/// guidelines or local laws. Users can report various types of problematic
/// content including spam, harassment, illegal material, or inappropriate imagery.
class Report extends RegularModel<Report> {
  /// The reported user's profile
  late final BelongsTo<Profile> reportedUser;

  /// The reported content (if reporting a specific post)
  late final BelongsTo<Model> reportedContent;

  Report.fromMap(super.map, super.ref) : super.fromMap() {
    final validUserPubkey = reportedUserPubkey?.length == 64
        ? reportedUserPubkey
        : null;
    reportedUser = BelongsTo(
      ref,
      validUserPubkey != null
          ? RequestFilter<Profile>(authors: {validUserPubkey}).toRequest()
          : null,
    );

    final validContentId = reportedContentId?.length == 64
        ? reportedContentId
        : null;
    reportedContent = BelongsTo(
      ref,
      validContentId != null ? Request.fromIds({validContentId}) : null,
    );
  }

  /// The reason for reporting this content
  String get reason => event.content;

  /// The public key of the reported user
  String? get reportedUserPubkey => event.getFirstTagValue('p');

  /// The ID of the reported content
  String? get reportedContentId => event.getFirstTagValue('e');

  /// The type of violation being reported
  ReportType? get violationType {
    final pTag = event.getTagSet('p').firstOrNull;
    final eTag = event.getTagSet('e').firstOrNull;
    final xTag = event.getTagSet('x').firstOrNull;

    if (pTag != null && pTag.length > 3) {
      return ReportType.fromString(pTag[3]);
    } else if (eTag != null && eTag.length > 3) {
      return ReportType.fromString(eTag[3]);
    } else if (xTag != null && xTag.length > 3) {
      return ReportType.fromString(xTag[3]);
    }
    return null;
  }

  /// The file hash being reported (for media content)
  String? get reportedFileHash => event.getFirstTagValue('x');

  /// The server where the reported media can be found
  String? get mediaServerUrl => event.getFirstTagValue('server');

  /// Whether this report targets a user profile
  bool get isProfileReport =>
      reportedUserPubkey != null && reportedContentId == null;

  /// Whether this report targets specific content
  bool get isContentReport => reportedContentId != null;

  /// Whether this report targets media files
  bool get isMediaReport => reportedFileHash != null;
}

/// Types of content violations that can be reported
enum ReportType {
  /// Sexual or nude imagery
  nudity,

  /// Malicious software or links
  malware,

  /// Offensive or hateful language
  profanity,

  /// Content that may be illegal in some jurisdictions
  illegal,

  /// Unwanted promotional content
  spam,

  /// Someone pretending to be another person
  impersonation,

  /// Other violations not covered by specific categories
  other;

  /// Creates a ReportType from a string value
  static ReportType? fromString(String value) {
    switch (value.toLowerCase()) {
      case 'nudity':
        return ReportType.nudity;
      case 'malware':
        return ReportType.malware;
      case 'profanity':
        return ReportType.profanity;
      case 'illegal':
        return ReportType.illegal;
      case 'spam':
        return ReportType.spam;
      case 'impersonation':
        return ReportType.impersonation;
      case 'other':
        return ReportType.other;
      default:
        return null;
    }
  }

  /// Returns the string representation for protocol use
  String get protocolValue {
    switch (this) {
      case ReportType.nudity:
        return 'nudity';
      case ReportType.malware:
        return 'malware';
      case ReportType.profanity:
        return 'profanity';
      case ReportType.illegal:
        return 'illegal';
      case ReportType.spam:
        return 'spam';
      case ReportType.impersonation:
        return 'impersonation';
      case ReportType.other:
        return 'other';
    }
  }

  /// Human-readable description of this report type
  String get displayName {
    switch (this) {
      case ReportType.nudity:
        return 'Sexual Content';
      case ReportType.malware:
        return 'Malicious Software';
      case ReportType.profanity:
        return 'Hate Speech';
      case ReportType.illegal:
        return 'Illegal Content';
      case ReportType.spam:
        return 'Spam';
      case ReportType.impersonation:
        return 'Impersonation';
      case ReportType.other:
        return 'Other Violation';
    }
  }
}

/// Create and submit content reports for moderation.
///
/// Example usage:
/// ```dart
/// // Report spam content
/// final report = await PartialReport.forContent(
///   contentId: 'abc123...',
///   authorPubkey: 'def456...',
///   violationType: ReportType.spam,
///   reason: 'Repeated promotional posts',
/// ).signWith(signer);
///
/// // Report user impersonation
/// final report = await PartialReport.forProfile(
///   userPubkey: 'fake789...',
///   violationType: ReportType.impersonation,
///   reason: 'Pretending to be a celebrity',
/// ).signWith(signer);
/// ```
class PartialReport extends RegularPartialModel<Report> {
  PartialReport.fromMap(super.map) : super.fromMap();

  /// The reason for reporting this content
  String? get reason => event.content.isEmpty ? null : event.content;

  /// Sets the reason for reporting
  set reason(String? value) => event.content = value ?? '';

  /// The public key of the reported user
  String? get reportedUserPubkey => event.getFirstTagValue('p');

  /// Sets the reported user's public key
  set reportedUserPubkey(String? value) => event.setTagValue('p', value);

  /// The ID of the reported content
  String? get reportedContentId => event.getFirstTagValue('e');

  /// Sets the reported content ID
  set reportedContentId(String? value) => event.setTagValue('e', value);

  /// The file hash being reported (for media content)
  String? get reportedFileHash => event.getFirstTagValue('x');

  /// Sets the reported file hash
  set reportedFileHash(String? value) => event.setTagValue('x', value);

  /// The server where the reported media can be found
  String? get mediaServerUrl => event.getFirstTagValue('server');

  /// Sets the media server URL
  set mediaServerUrl(String? value) => event.setTagValue('server', value);

  /// Creates a report for specific content
  ///
  /// [contentId] - The ID of the content being reported
  /// [authorPubkey] - The public key of the content's author
  /// [violationType] - The type of violation
  /// [reason] - Optional detailed explanation
  PartialReport.forContent({
    required String contentId,
    required String authorPubkey,
    required ReportType violationType,
    String? reason,
  }) {
    // Add content reference with violation type
    event.addTag('e', [contentId, '', violationType.protocolValue]);
    // Add author reference
    event.addTag('p', [authorPubkey]);
    if (reason != null) this.reason = reason;
  }

  /// Creates a report for a user profile
  ///
  /// [userPubkey] - The public key of the user being reported
  /// [violationType] - The type of violation
  /// [reason] - Optional detailed explanation
  PartialReport.forProfile({
    required String userPubkey,
    required ReportType violationType,
    String? reason,
  }) {
    // Add user reference with violation type
    event.addTag('p', [userPubkey, '', violationType.protocolValue]);
    if (reason != null) this.reason = reason;
  }

  /// Creates a report for media content
  ///
  /// [fileHash] - The hash of the media file
  /// [contentId] - The ID of the event containing the media
  /// [violationType] - The type of violation
  /// [reason] - Optional detailed explanation
  /// [serverUrl] - Optional URL where the media can be found
  PartialReport.forMedia({
    required String fileHash,
    required String contentId,
    required ReportType violationType,
    String? reason,
    String? serverUrl,
  }) {
    // Add file hash with violation type
    event.addTag('x', [fileHash, '', violationType.protocolValue]);
    // Add event reference
    event.addTag('e', [contentId, '', violationType.protocolValue]);
    if (serverUrl != null) mediaServerUrl = serverUrl;
    if (reason != null) this.reason = reason;
  }

  /// Basic constructor for custom report types
  PartialReport({
    String? reason,
    String? reportedUserPubkey,
    String? reportedContentId,
    String? reportedFileHash,
    String? mediaServerUrl,
  }) {
    if (reason != null) this.reason = reason;
    if (reportedUserPubkey != null) {
      this.reportedUserPubkey = reportedUserPubkey;
    }
    if (reportedContentId != null) this.reportedContentId = reportedContentId;
    if (reportedFileHash != null) this.reportedFileHash = reportedFileHash;
    if (mediaServerUrl != null) mediaServerUrl = mediaServerUrl;
  }
}

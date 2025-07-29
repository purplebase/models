import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    storage =
        container.read(storageNotifierProvider.notifier)
            as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.cancel();
    await storage.clear();
    container.dispose();
  });

  group('Report', () {
    test('report content with forContent constructor', () async {
      const contentId =
          'abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
      const authorPubkey =
          'ef123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final report = PartialReport.forContent(
        contentId: contentId,
        authorPubkey: authorPubkey,
        violationType: ReportType.spam,
        reason: 'Repeated promotional posts',
      ).dummySign(nielPubkey);

      expect(report.reason, 'Repeated promotional posts');
      expect(report.reportedContentId, contentId);
      expect(report.reportedUserPubkey, authorPubkey);
      expect(report.violationType, ReportType.spam);
      expect(report.isContentReport, true);
      expect(report.isProfileReport, false);
      expect(report.isMediaReport, false);
    });

    test('report profile with forProfile constructor', () {
      const userPubkey =
          'abc123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final report = PartialReport.forProfile(
        userPubkey: userPubkey,
        violationType: ReportType.impersonation,
        reason: 'Pretending to be a celebrity',
      ).dummySign(nielPubkey);

      expect(report.reason, 'Pretending to be a celebrity');
      expect(report.reportedUserPubkey, userPubkey);
      expect(report.reportedContentId, null);
      expect(report.violationType, ReportType.impersonation);
      expect(report.isContentReport, false);
      expect(report.isProfileReport, true);
      expect(report.isMediaReport, false);
    });

    test('report media with forMedia constructor', () {
      const fileHash =
          'hash123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';
      const contentId =
          'cont123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final report = PartialReport.forMedia(
        fileHash: fileHash,
        contentId: contentId,
        violationType: ReportType.malware,
        reason: 'Contains malicious software',
        serverUrl: 'https://malicious-server.example.com',
      ).dummySign(nielPubkey);

      expect(report.reason, 'Contains malicious software');
      expect(report.reportedFileHash, fileHash);
      expect(report.reportedContentId, contentId);
      expect(report.mediaServerUrl, 'https://malicious-server.example.com');
      expect(report.violationType, ReportType.malware);
      expect(report.isMediaReport, true);
      expect(report.isContentReport, true);
    });

    test('basic constructor', () {
      const userPubkey =
          'user123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final report = PartialReport(
        reason: 'General violation',
        reportedUserPubkey: userPubkey,
      ).dummySign(nielPubkey);

      expect(report.reason, 'General violation');
      expect(report.reportedUserPubkey, userPubkey);
      expect(report.reportedContentId, null);
      expect(report.reportedFileHash, null);
      expect(report.mediaServerUrl, null);
    });

    test('ReportType enum functionality', () {
      // Test fromString
      expect(ReportType.fromString('nudity'), ReportType.nudity);
      expect(ReportType.fromString('SPAM'), ReportType.spam);
      expect(ReportType.fromString('Invalid'), null);

      // Test protocolValue
      expect(ReportType.nudity.protocolValue, 'nudity');
      expect(ReportType.malware.protocolValue, 'malware');
      expect(ReportType.impersonation.protocolValue, 'impersonation');

      // Test displayName
      expect(ReportType.nudity.displayName, 'Sexual Content');
      expect(ReportType.malware.displayName, 'Malicious Software');
      expect(ReportType.profanity.displayName, 'Hate Speech');
      expect(ReportType.illegal.displayName, 'Illegal Content');
      expect(ReportType.spam.displayName, 'Spam');
      expect(ReportType.impersonation.displayName, 'Impersonation');
      expect(ReportType.other.displayName, 'Other Violation');
    });

    test('violation type parsing from tags', () {
      // Test e tag with violation type
      const contentId =
          'cont123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';
      const authorPubkey =
          'auth123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final report = PartialReport.forContent(
        contentId: contentId,
        authorPubkey: authorPubkey,
        violationType: ReportType.illegal,
      ).dummySign(nielPubkey);

      expect(report.violationType, ReportType.illegal);
    });

    test('partial model setters', () {
      final partial = PartialReport();

      partial.reason = 'Test reason';
      partial.reportedUserPubkey = 'pubkey123';
      partial.reportedContentId = 'content123';
      partial.reportedFileHash = 'hash123';
      partial.mediaServerUrl = 'https://server.example.com';

      expect(partial.reason, 'Test reason');
      expect(partial.reportedUserPubkey, 'pubkey123');
      expect(partial.reportedContentId, 'content123');
      expect(partial.reportedFileHash, 'hash123');
      expect(partial.mediaServerUrl, 'https://server.example.com');
    });

    test('relationships with valid IDs', () async {
      // Create valid test data with proper hex IDs
      const validUserPubkey =
          'ef123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final note = PartialNote('Test content').dummySign(validUserPubkey);
      final profile = PartialProfile(
        name: 'Test User',
      ).dummySign(validUserPubkey);

      await storage.save({note, profile});

      final report = PartialReport.forContent(
        contentId: note.event.id,
        authorPubkey: validUserPubkey,
        violationType: ReportType.spam,
        reason: 'This is spam',
      ).dummySign(nielPubkey);

      await storage.save({report});

      // Test that relationships are properly set up
      expect(report.reportedUser.req, isNotNull);
      expect(report.reportedContent.req, isNotNull);
      expect(report.reportedUser.req!.filters.first.authors, {validUserPubkey});
      expect(report.reportedContent.req!.filters.first.ids, {note.event.id});
    });

    test('event kind and structure', () {
      const contentId =
          'cont123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';
      const authorPubkey =
          'auth123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final report = PartialReport.forContent(
        contentId: contentId,
        authorPubkey: authorPubkey,
        violationType: ReportType.profanity,
        reason: 'Offensive language',
      ).dummySign(nielPubkey);

      expect(report.event.kind, 1984);
      expect(report.event.content, 'Offensive language');

      // Check that tags are properly structured
      final eTags = report.event.getTagSet('e');
      expect(eTags.length, 1);
      expect(eTags.first[0], 'e');
      expect(eTags.first[1], contentId);
      expect(eTags.first[2], '');
      expect(eTags.first[3], 'profanity');

      final pTags = report.event.getTagSet('p');
      expect(pTags.length, 1);
      expect(pTags.first[0], 'p');
      expect(pTags.first[1], authorPubkey);
    });

    test('media report structure', () {
      const fileHash =
          'hash123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';
      const contentId =
          'cont123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final report = PartialReport.forMedia(
        fileHash: fileHash,
        contentId: contentId,
        violationType: ReportType.nudity,
        serverUrl: 'https://server.example.com',
      ).dummySign(nielPubkey);

      // Check x tag (file hash)
      final xTags = report.event.getTagSet('x');
      expect(xTags.length, 1);
      expect(xTags.first[0], 'x');
      expect(xTags.first[1], fileHash);
      expect(xTags.first[2], '');
      expect(xTags.first[3], 'nudity');

      // Check e tag (content ID)
      final eTags = report.event.getTagSet('e');
      expect(eTags.length, 1);
      expect(eTags.first[0], 'e');
      expect(eTags.first[1], contentId);
      expect(eTags.first[2], '');
      expect(eTags.first[3], 'nudity');

      // Check server tag
      expect(
        report.event.getFirstTagValue('server'),
        'https://server.example.com',
      );
    });

    test('empty report', () {
      final report = PartialReport().dummySign(nielPubkey);

      expect(report.reason, '');
      expect(report.reportedUserPubkey, null);
      expect(report.reportedContentId, null);
      expect(report.reportedFileHash, null);
      expect(report.mediaServerUrl, null);
      expect(report.violationType, null);
      expect(report.isContentReport, false);
      expect(report.isProfileReport, false);
      expect(report.isMediaReport, false);
    });

    test('from/to partial model', () {
      const userPubkey =
          'user123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final report = PartialReport.forProfile(
        userPubkey: userPubkey,
        violationType: ReportType.spam,
        reason: 'Test report',
      ).dummySign(nielPubkey);

      final partial = report.toPartial() as PartialReport;
      expect(partial.reason, 'Test report');
      expect(partial.reportedUserPubkey, userPubkey);
    });
  });
}

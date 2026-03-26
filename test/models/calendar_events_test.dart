import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late DummyStorageNotifier storage;

  setUp(() async {
    container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
    storage =
        container.read(storageNotifierProvider.notifier) as DummyStorageNotifier;
  });

  tearDown(() async {
    await storage.clear();
    container.dispose();
  });

  group('DateBasedCalendarEvent', () {
    test('basic date event creation', () {
      final event = PartialDateBasedCalendarEvent(
        title: 'Independence Day',
        startDate: '2024-07-04',
        identifier: 'july4',
      ).dummySign(nielPubkey);

      expect(event.identifier, 'july4');
      expect(event.title, 'Independence Day');
      expect(event.startDate, '2024-07-04');
      expect(event.endDate, null);
      expect(event.isSingleDay, true);
    });

    test('multi-day event', () {
      final event = PartialDateBasedCalendarEvent(
        title: 'Summer Conference',
        startDate: '2024-07-15',
        endDate: '2024-07-17',
        identifier: 'conf2024',
        location: 'Convention Center',
      ).dummySign(nielPubkey);

      expect(event.identifier, 'conf2024');
      expect(event.title, 'Summer Conference');
      expect(event.startDate, '2024-07-15');
      expect(event.endDate, '2024-07-17');
      expect(event.location, 'Convention Center');
      expect(event.isSingleDay, false);
      expect(event.durationInDays, greaterThan(1));
    });

    test('event kind and structure', () {
      final event = PartialDateBasedCalendarEvent(
        title: 'Test Event',
        startDate: '2024-12-25',
        identifier: 'test',
      ).dummySign(nielPubkey);

      expect(event.event.kind, 31922);
      expect(event.event.getFirstTagValue('d'), 'test');
      expect(event.event.getFirstTagValue('title'), 'Test Event');
      expect(event.event.getFirstTagValue('start'), '2024-12-25');
    });
  });

  group('TimeBasedCalendarEvent', () {
    test('basic time event creation', () {
      final startTime = DateTime(2024, 7, 4, 12, 0);

      final event = PartialTimeBasedCalendarEvent(
        title: 'Independence Day Parade',
        startTime: startTime,
        identifier: 'july4-parade',
      ).dummySign(nielPubkey);

      expect(event.identifier, 'july4-parade');
      expect(event.title, 'Independence Day Parade');
      expect(
        event.startTimestamp,
        (startTime.millisecondsSinceEpoch / 1000).round(),
      );
      expect(event.endTimestamp, null);
    });

    test('event with end time', () {
      final startTime = DateTime(2024, 12, 31, 23, 30);
      final endTime = DateTime(2025, 1, 1, 1, 0);

      final event = PartialTimeBasedCalendarEvent(
        title: 'New Year Countdown',
        startTime: startTime,
        endTime: endTime,
        identifier: 'countdown-2025',
        location: 'Times Square',
      ).dummySign(nielPubkey);

      expect(event.identifier, 'countdown-2025');
      expect(event.title, 'New Year Countdown');
      expect(event.location, 'Times Square');
      expect(
        event.startTimestamp,
        (startTime.millisecondsSinceEpoch / 1000).round(),
      );
      expect(
        event.endTimestamp,
        (endTime.millisecondsSinceEpoch / 1000).round(),
      );
    });

    test('event kind and structure', () {
      final startTime = DateTime(2024, 8, 15, 14, 0);

      final event = PartialTimeBasedCalendarEvent(
        title: 'Team Meeting',
        startTime: startTime,
        identifier: 'meeting',
      ).dummySign(nielPubkey);

      expect(event.event.kind, 31923);
      expect(event.event.getFirstTagValue('d'), 'meeting');
      expect(event.event.getFirstTagValue('title'), 'Team Meeting');
      expect(
        event.event.getFirstTagValue('start'),
        (startTime.millisecondsSinceEpoch / 1000).round().toString(),
      );
    });
  });

  group('Calendar', () {
    test('basic calendar creation', () {
      final calendar = PartialCalendar(
        title: 'My Events 2024',
        identifier: 'my-events-2024',
      ).dummySign(nielPubkey);

      expect(calendar.identifier, 'my-events-2024');
      expect(calendar.title, 'My Events 2024');
      expect(calendar.description, '');
      expect(calendar.eventAddresses, isEmpty);
    });

    test('calendar with description', () {
      final calendar = PartialCalendar(
        title: 'Work Calendar',
        identifier: 'work-cal',
        description: 'All work-related events',
      ).dummySign(nielPubkey);

      expect(calendar.title, 'Work Calendar');
      expect(calendar.description, 'All work-related events');
      expect(calendar.eventAddresses, isEmpty);
    });

    test('event kind and structure', () {
      final calendar = PartialCalendar(
        title: 'Test Calendar',
        identifier: 'test-cal',
      ).dummySign(nielPubkey);

      expect(calendar.event.kind, 31924);
      expect(calendar.event.getFirstTagValue('d'), 'test-cal');
      expect(calendar.event.getFirstTagValue('title'), 'Test Calendar');
      expect(calendar.event.getTagSetValues('a'), isEmpty);
    });

    test('partial model methods', () {
      final partial = PartialCalendar(title: 'Test', identifier: 'test');

      // Test event address management
      partial.addEventAddress('31922:pubkey123:event1');
      partial.addEventAddress('31922:pubkey456:event2');
      expect(partial.eventAddresses, {
        '31922:pubkey123:event1',
        '31922:pubkey456:event2',
      });

      partial.removeEventAddress('31922:pubkey123:event1');
      expect(partial.eventAddresses, {'31922:pubkey456:event2'});
    });
  });

  group('CalendarEventRSVP', () {
    test('accepted RSVP', () {
      const eventAddress =
          '31922:abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:event456';

      final rsvp = PartialCalendarEventRSVP(
        eventAddress: eventAddress,
        status: RSVPStatus.accepted,
        note: 'Looking forward to it!',
      ).dummySign(nielPubkey);

      expect(rsvp.eventAddress, eventAddress);
      expect(rsvp.status, RSVPStatus.accepted);
      expect(rsvp.note, 'Looking forward to it!');
    });

    test('declined RSVP', () {
      const eventAddress =
          '31922:ef123456789abcdef123456789abcdef123456789abcdef123456789abcdef12:event123';

      final rsvp = PartialCalendarEventRSVP(
        eventAddress: eventAddress,
        status: RSVPStatus.declined,
        note: 'Sorry, cannot make it',
      ).dummySign(nielPubkey);

      expect(rsvp.status, RSVPStatus.declined);
      expect(rsvp.note, 'Sorry, cannot make it');
    });

    test('event kind and structure', () {
      const eventAddress =
          '31922:abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab:test456';

      final rsvp = PartialCalendarEventRSVP(
        eventAddress: eventAddress,
        status: RSVPStatus.accepted,
        note: 'Yes!',
      ).dummySign(nielPubkey);

      expect(rsvp.event.kind, 31925);
      expect(rsvp.event.getFirstTagValue('a'), eventAddress);
      expect(rsvp.event.getFirstTagValue('status'), 'accepted');
      expect(rsvp.event.content, 'Yes!');
    });
  });

  group('RSVPStatus enum', () {
    test('enum values', () {
      expect(RSVPStatus.accepted.protocolValue, 'accepted');
      expect(RSVPStatus.declined.protocolValue, 'declined');
      expect(RSVPStatus.tentative.protocolValue, 'tentative');
    });

    test('fromString conversion', () {
      expect(RSVPStatus.fromString('accepted'), RSVPStatus.accepted);
      expect(RSVPStatus.fromString('declined'), RSVPStatus.declined);
      expect(RSVPStatus.fromString('tentative'), RSVPStatus.tentative);
      expect(RSVPStatus.fromString('invalid'), null);
    });
  });

  group('AvailabilityStatus enum', () {
    test('enum values', () {
      expect(AvailabilityStatus.free.protocolValue, 'free');
      expect(AvailabilityStatus.busy.protocolValue, 'busy');
    });

    test('fromString conversion', () {
      expect(AvailabilityStatus.fromString('free'), AvailabilityStatus.free);
      expect(AvailabilityStatus.fromString('busy'), AvailabilityStatus.busy);
      expect(AvailabilityStatus.fromString('invalid'), null);
    });
  });

  group('Calendar system integration', () {
    test('create calendar with event and RSVP', () async {
      // Create a calendar
      final calendar = PartialCalendar(
        title: 'Party Events',
        identifier: 'party-calendar',
      ).dummySign(nielPubkey);

      // Create a date-based event
      final partyEvent = PartialDateBasedCalendarEvent(
        title: 'Summer Pool Party',
        startDate: '2024-07-20',
        identifier: 'summer-party',
        location: 'Backyard Pool',
      ).dummySign(nielPubkey);

      // Create RSVP using the event's addressable ID format
      final eventAddress =
          '${partyEvent.event.kind}:${partyEvent.event.pubkey}:summer-party';
      final rsvp = PartialCalendarEventRSVP(
        eventAddress: eventAddress,
        status: RSVPStatus.accepted,
        note: 'Can\'t wait for the party!',
      ).dummySign(nielPubkey);

      await storage.save({calendar, partyEvent, rsvp});

      expect(partyEvent.title, 'Summer Pool Party');
      expect(rsvp.eventAddress, eventAddress);
      expect(rsvp.status, RSVPStatus.accepted);
      expect(rsvp.note, 'Can\'t wait for the party!');
    });
  });
}

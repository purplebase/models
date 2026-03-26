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

  group('PinList', () {
    test('basic pin list creation', () {
      const event1 =
          'event123456789abcdef123456789abcdef123456789abcdef123456789abcdef12';
      const event2 =
          'event789abcdef123456789abcdef123456789abcdef123456789abcdef123456';

      final partial = PartialPinList();
      partial.pinnedContent = {event1, event2};
      final pinList = partial.dummySign(nielPubkey);

      expect(pinList.pinnedContent, {event1, event2});
    });

    test('event kind and structure', () {
      const testEvent =
          'test456789abcdef123456789abcdef123456789abcdef123456789abcdef12';

      final partial = PartialPinList();
      partial.pinnedContent = {testEvent};
      final pinList = partial.dummySign(nielPubkey);

      expect(pinList.event.kind, 10001);

      // Check e tags for pinned events
      final eTags = pinList.event.getTagSet('e');
      expect(eTags.length, 1);
      expect(eTags.first[1], testEvent);
    });

    test('partial model methods', () {
      final partial = PartialPinList();

      // Test event management
      partial.addPinnedContent('event1');
      partial.addPinnedContent('event2');
      expect(partial.pinnedContent, {'event1', 'event2'});

      partial.removePinnedContent('event1');
      expect(partial.pinnedContent, {'event2'});
    });
  });
}

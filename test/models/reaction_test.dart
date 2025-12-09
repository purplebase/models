import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;

  setUpAll(() async {
        container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
  });

  tearDownAll(() async {
    container.dispose();
      });

  group('Reaction', () {
    test('reaction', () async {
      final a = PartialNote('Note A').dummySign(nielPubkey);
      final profile = PartialProfile(name: 'neil').dummySign(nielPubkey);

      await container.read(storageNotifierProvider.notifier).save({a, profile});

      final reaction =
          PartialReaction(reactedOn: a, emojiTag: ('test', 'test://t'))
              .dummySign(nielPubkey);
      expect(reaction.emojiTag, equals(('test', 'test://t')));
      expect(reaction.reactedOn.req!.filters.first.ids, {a.event.id});
      expect(reaction.reactedOn.value, a);
      expect(reaction.author.value, profile);
    });
  });
}

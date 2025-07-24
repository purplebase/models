import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;

  setUp(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    ref = container.read(refProvider);
  });

  tearDown(() async {
    container.dispose();
  });

  group('App', () {
    test('app', () {
      final partialApp = PartialApp()
        ..identifier = 'w'
        ..description = 'test app';
      final app = partialApp.dummySign(
        'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1',
      );

      expect(app.event.kind, 32267);
      expect(app.description, 'test app');
      expect(
        app.id,
        '32267:f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1:w',
      );
      expect(app.event.id, hasLength(64));
      expect(
        app.event.shareableId,
        'naddr1qqqhwq3q7dh35fe8k74s9clkaxvyrnftfkt9t7x05xzt6ntg7njvwtdcuhqsxpqqqplqknw8nmm',
      );
      expect(App.fromMap(app.toMap(), ref), app);
    });
  });
}

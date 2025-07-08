import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

void main() {
  late ProviderContainer container;

  setUpAll(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
  });

  group('Release', () {
    test('release', () {
      final partialRelease = PartialRelease()
        ..identifier = 'com.example.app@0.1.2';
      final release = partialRelease.dummySign(
          'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1');
      expect(release.identifier, 'com.example.app@0.1.2');
      expect(release.appIdentifier, 'com.example.app');
      expect(release.version, '0.1.2');

      final newPartialRelease = PartialRelease(newFormat: false)
        ..identifier = 'com.example.app@0.1.2';
      final newRelease = newPartialRelease.dummySign(
          'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1');
      expect(newRelease.identifier, 'com.example.app@0.1.2');
      expect(newRelease.appIdentifier, 'com.example.app');
      expect(newRelease.version, '0.1.2');
    });
  });
}

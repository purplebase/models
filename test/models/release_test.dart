import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import '../helpers.dart';

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
        'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1',
      );
      expect(release.identifier, 'com.example.app@0.1.2');
      expect(release.appIdentifier, 'com.example.app');
      expect(release.version, '0.1.2');

      final newPartialRelease = PartialRelease(newFormat: false)
        ..identifier = 'com.example.app@0.1.2';
      final newRelease = newPartialRelease.dummySign(
        'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1',
      );
      expect(newRelease.identifier, 'com.example.app@0.1.2');
      expect(newRelease.appIdentifier, 'com.example.app');
      expect(newRelease.version, '0.1.2');
    });

    test('release and file metadata relationship', () async {
      // Use the same pubkey for both models
      final pubkey = franzapPubkey;
      // Create a FileMetadata
      final partialFile = PartialFileMetadata()
        ..version = '1.0.0'
        ..appIdentifier = 'com.example.app';
      final fileMetadata = partialFile.dummySign(pubkey);

      // Create a Release that references the FileMetadata by id
      final partialRelease = PartialRelease()
        ..identifier = 'com.example.app@1.0.0';
      // Add the file metadata id as an 'e' tag (as per Release.fromMap)
      partialRelease.event.addTag('e', [fileMetadata.id]);
      final release = partialRelease.dummySign(pubkey);

      // Save both models to storage
      final storage =
          container.read(storageNotifierProvider.notifier)
              as DummyStorageNotifier;
      await storage.save({fileMetadata, release});

      // Load from storage to ensure relationships work after persistence
      final allReleases = await storage.query(
        Request<Release>([
          RequestFilter<Release>(kinds: {30063}),
        ]),
      );
      final allFiles = await storage.query(
        Request<FileMetadata>([
          RequestFilter<FileMetadata>(kinds: {1063}),
        ]),
      );
      final loadedRelease = allReleases.firstWhere((r) => r.id == release.id);
      final loadedFileMetadata = allFiles.firstWhere(
        (f) => f.id == fileMetadata.id,
      );

      // Check that the Release lists the FileMetadata
      expect(
        loadedRelease.fileMetadatas.toList(),
        contains(loadedFileMetadata),
      );
      // Check that the FileMetadata's release relationship finds the Release
      expect(loadedFileMetadata.release.value, loadedRelease);
    });
  });
}

part of models;

@GeneratePartialModel()
class SoftwareAsset extends FileMetadata {
  SoftwareAsset.fromMap(super.map, super.ref) : super.fromMap();

  String get minOSVersion => event.getFirstTagValue('min_os_version')!;
  String get targetOSVersion => event.getFirstTagValue('target_os_version')!;

  @override
  String get appIdentifier => event.getFirstTagValue('i')!;
  @override
  String get version => event.getFirstTagValue('version')!;
}

class PartialSoftwareAsset extends PartialFileMetadata
    with PartialSoftwareAssetMixin {}

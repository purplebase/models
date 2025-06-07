part of models;

@GeneratePartialModel()
class Release extends ParameterizableReplaceableModel<Release> {
  late final BelongsTo<App> app;
  late final HasMany<SoftwareAsset> fileMetadatas;

  Release.fromMap(super.map, super.ref) : super.fromMap() {
    app = BelongsTo(
        ref,
        event.containsTag('a')
            ? RequestFilter.fromReplaceable(event.getFirstTagValue('a')!)
            // New format
            : RequestFilter(
                authors: {event.pubkey},
                tags: {
                  '#d': {event.identifier}
                },
                limit: 1,
              ));
    fileMetadatas =
        HasMany(ref, RequestFilter(ids: event.getTagSetValues('e').toSet()));
  }

  String? get releaseNotes => event.content.isEmpty ? null : event.content;
  String? get url => event.getFirstTagValue('url');

  @override
  String get identifier {
    return '$appIdentifier@$version';
  }

  String get appIdentifier {
    // With fallback to legacy method
    return event.getFirstTagValue('i') ?? event.identifier.split('@').first;
  }

  String get version {
    // With fallback to legacy method
    return event.getFirstTagValue('version') ??
        event.identifier.split('@').last;
  }
}

class PartialRelease extends ParameterizableReplaceablePartialEvent<Release>
    with PartialReleaseMixin {
  final bool oldFormat;
  PartialRelease({this.oldFormat = true});

  @override
  String? get appIdentifier {
    if (oldFormat) {
      final value = event.identifier?.split('@').firstOrNull;
      if (value == null) return null;
      return value.isEmpty ? null : value;
    }
    return event.getFirstTagValue('i');
  }

  @override
  String? get version {
    if (oldFormat) {
      final value = event.identifier?.split('@').lastOrNull;
      if (value == null) return null;
      return value.isEmpty ? null : value;
    }
    return event.getFirstTagValue('version');
  }

  @override
  set appIdentifier(String? value) {
    throw UnimplementedError('Use identifier setter');
  }

  @override
  set version(String? value) {
    throw UnimplementedError('Use identifier setter');
  }
}

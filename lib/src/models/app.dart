part of models;

class App extends ParameterizableReplaceableModel<App> {
  late final HasMany<Release> releases;
  late final BelongsTo<Release> latestRelease;

  App.fromMap(super.map, super.ref) : super.fromMap() {
    releases = HasMany(
      ref,
      RequestFilter<Release>(tags: event.addressableIdTagMap).toRequest(),
    );
    latestRelease = BelongsTo(
      ref,
      // Legacy format
      event.containsTag('a')
          ? Request<Release>.fromIds({event.getFirstTagValue('a')!})
          // New format
          : RequestFilter<Release>(
              authors: {event.pubkey},
              tags: {
                '#i': {event.identifier},
              },
              limit: 1,
            ).toRequest(),
    );
  }

  String? get name => event.getFirstTagValue('name');
  String? get summary => event.getFirstTagValue('summary');
  String? get repository => event.getFirstTagValue('repository');
  String get description => event.content;
  String? get url => event.getFirstTagValue('url');
  String? get license => event.getFirstTagValue('license');
  Set<String> get icons => event.getTagSetValues('icon');
  Set<String> get images => event.getTagSetValues('image');
  Set<String> get platforms => event.getTagSetValues('f').toSet();
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for App
mixin PartialAppMixin on ParameterizableReplaceablePartialModel<App> {
  String? get name => event.getFirstTagValue('name');
  set name(String? value) => event.setTagValue('name', value);
  String? get summary => event.getFirstTagValue('summary');
  set summary(String? value) => event.setTagValue('summary', value);
  String? get repository => event.getFirstTagValue('repository');
  set repository(String? value) => event.setTagValue('repository', value);
  String? get description => event.content.isEmpty ? null : event.content;
  set description(String? value) => event.content = value ?? '';
  String? get url => event.getFirstTagValue('url');
  set url(String? value) => event.setTagValue('url', value);
  String? get license => event.getFirstTagValue('license');
  set license(String? value) => event.setTagValue('license', value);
  Set<String> get icons => event.getTagSetValues('icon');
  set icons(Set<String> value) => event.setTagValues('icon', value);
  void addIcon(String? value) => event.addTagValue('icon', value);
  void removeIcon(String? value) => event.removeTagWithValue('icon', value);
  Set<String> get images => event.getTagSetValues('image');
  set images(Set<String> value) => event.setTagValues('image', value);
  void addImage(String? value) => event.addTagValue('image', value);
  void removeImage(String? value) => event.removeTagWithValue('image', value);
  Set<String> get platforms => event.getTagSetValues('f');
  set platforms(Set<String> value) => event.setTagValues('f', value);
  void addPlatform(String? value) => event.addTagValue('f', value);
  void removePlatform(String? value) => event.removeTagWithValue('f', value);
}

class PartialApp extends ParameterizableReplaceablePartialModel<App>
    with PartialAppMixin {
  PartialApp.fromMap(super.map) : super.fromMap();
  PartialApp();
}

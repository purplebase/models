part of models;

/// An application event (kind 32267) representing a software application.
///
/// Apps are parameterizable replaceable events that contain metadata about
/// software applications, including name, description, and repository information.
/// They can have associated releases for distribution.
class App extends ParameterizableReplaceableModel<App> {
  late final HasMany<Release> releases;
  late final BelongsTo<Release> latestRelease;
  late final HasMany<AppCurationSet> appCurationSets;

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
    appCurationSets = HasMany(
      ref,
      RequestFilter<AppCurationSet>(
        tags: {
          '#a': {event.addressableId},
        },
      ).toRequest(),
    );
  }

  /// The application name
  String? get name => event.getFirstTagValue('name');

  /// Brief summary or tagline for the application
  String? get summary => event.getFirstTagValue('summary');

  /// URL to the source code repository
  String? get repository => event.getFirstTagValue('repository');

  /// Full description of the application (from event content)
  String get description => event.content;

  /// The application's website URL
  String? get url => event.getFirstTagValue('url');

  /// Software license under which the app is distributed
  String? get license => event.getFirstTagValue('license');

  /// Set of icon URLs for the application
  Set<String> get icons => event.getTagSetValues('icon');

  /// Set of screenshot or image URLs
  Set<String> get images => event.getTagSetValues('image');

  /// Set of supported platforms (e.g., 'android', 'ios', 'web')
  Set<String> get platforms => event.getTagSetValues('f').toSet();
}

/// Generated partial model mixin for App
mixin PartialAppMixin on ParameterizableReplaceablePartialModel<App> {
  /// The application name
  String? get name => event.getFirstTagValue('name');

  /// Sets the application name
  set name(String? value) => event.setTagValue('name', value);

  /// Brief summary or tagline for the application
  String? get summary => event.getFirstTagValue('summary');

  /// Sets the application summary
  set summary(String? value) => event.setTagValue('summary', value);

  /// URL to the source code repository
  String? get repository => event.getFirstTagValue('repository');

  /// Sets the repository URL
  set repository(String? value) => event.setTagValue('repository', value);

  /// Full description of the application
  String? get description => event.content.isEmpty ? null : event.content;

  /// Sets the application description
  set description(String? value) => event.content = value ?? '';

  /// The application's website URL
  String? get url => event.getFirstTagValue('url');

  /// Sets the website URL
  set url(String? value) => event.setTagValue('url', value);

  /// Software license under which the app is distributed
  String? get license => event.getFirstTagValue('license');

  /// Sets the software license
  set license(String? value) => event.setTagValue('license', value);

  /// Set of icon URLs for the application
  Set<String> get icons => event.getTagSetValues('icon');

  /// Sets the icon URLs
  set icons(Set<String> value) => event.setTagValues('icon', value);

  /// Adds an icon URL to the application
  void addIcon(String? value) => event.addTagValue('icon', value);

  /// Removes an icon URL from the application
  void removeIcon(String? value) => event.removeTagWithValue('icon', value);

  /// Set of screenshot or image URLs
  Set<String> get images => event.getTagSetValues('image');

  /// Sets the image URLs
  set images(Set<String> value) => event.setTagValues('image', value);

  /// Adds an image URL to the application
  void addImage(String? value) => event.addTagValue('image', value);

  /// Removes an image URL from the application
  void removeImage(String? value) => event.removeTagWithValue('image', value);

  /// Set of supported platforms
  Set<String> get platforms => event.getTagSetValues('f');

  /// Sets the supported platforms
  set platforms(Set<String> value) => event.setTagValues('f', value);

  /// Adds a supported platform
  void addPlatform(String? value) => event.addTagValue('f', value);

  /// Removes a supported platform
  void removePlatform(String? value) => event.removeTagWithValue('f', value);
}

/// Create and sign new app events.
class PartialApp extends ParameterizableReplaceablePartialModel<App>
    with PartialAppMixin {
  PartialApp.fromMap(super.map) : super.fromMap();

  /// Creates a new application event
  PartialApp();
}

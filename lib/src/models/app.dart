part of models;

@GeneratePartialModel()
class App extends ParameterizableReplaceableModel<App> {
  late final HasMany<Release> releases;
  late final BelongsTo<Release> latestRelease;
  App.fromMap(super.map, super.ref) : super.fromMap() {
    releases = HasMany(ref, RequestFilter(tags: event.addressableIdTagMap));
    latestRelease = BelongsTo(
        ref, RequestFilter.fromReplaceable(event.getFirstTagValue('a')!));
  }

  String? get name => event.getFirstTagValue('name');
  String? get summary => event.getFirstTagValue('summary');
  String? get repository => event.getFirstTagValue('repository');
  String get description => event.content;
  String get identifier => event.identifier;
  String? get url => event.getFirstTagValue('url');
  String? get license => event.getFirstTagValue('license');
  Set<String> get icons => event.getTagSetValues('icon');
  Set<String> get images => event.getTagSetValues('image');
  Set<String> get platforms => event.getTagSetValues('f').toSet();

  // PartialApp copyWith({
  //   String? name,
  //   String? repository,
  //   String? description,
  //   String? url,
  // }) {
  //   // Note: This copyWith creates a new PartialApp. Due to PartialApp's current design,
  //   // 'license', 'icons', and 'images' from the original App are not handled here as
  //   // PartialApp does not provide direct setters or a constructor argument for them.
  //   final partial = PartialApp();
  //   partial.name = name ?? this.name;
  //   partial.repository = repository ?? this.repository;
  //   partial.description = description ?? this.description;
  //   partial.url = url ?? this.url;
  //   return partial;
  // }
}

class PartialApp extends ParameterizableReplaceablePartialEvent<App>
    with PartialAppMixin {
  // set description(String? value) => event.content = value ?? '';
  // set name(String? value) => event.setTagValue('name', value);
  // set repository(String? value) => event.setTagValue('repository', value);
  // set url(String? value) => event.setTagValue('url', value);
  // set platforms(Set<String> value) => event.setTagValues('f', value);
  // set icons(Set<String> value) => event.setTagValues('icon', value);
  // set images(Set<String> value) => event.setTagValues('image', value);
  // set summary(String? value) => event.setTagValue('summary', value);
  // set license(String? value) => event.setTagValue('license', value);

  // void addIcon(String value) => event.addTagValue('icon', value);
  // void addImage(String value) => event.addTagValue('image', value);

  // String? get name => event.getFirstTagValue('name');
  // String? get summary => event.getFirstTagValue('summary');
  // String? get repository => event.getFirstTagValue('repository');
  // String? get description => event.content.isEmpty ? null : event.content;
  // String? get url => event.getFirstTagValue('url');
  // String? get license => event.getFirstTagValue('license');
  // Set<String> get icons => event.getTagSetValues('icon');
  // Set<String> get images => event.getTagSetValues('image');
  // Set<String> get platforms => event.getTagSetValues('f').toSet();
}

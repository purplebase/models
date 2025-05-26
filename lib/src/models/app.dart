part of models;

@GeneratePartialModel()
class App extends ParameterizableReplaceableModel<App> {
  late final HasMany<Release> releases;
  late final BelongsTo<Release> latestRelease;
  App.fromMap(super.map, super.ref) : super.fromMap() {
    releases = HasMany(ref, RequestFilter(tags: event.addressableIdTagMap));
    latestRelease = BelongsTo(
        ref,
        event.containsTag('a')
            ? RequestFilter.fromReplaceable(event.getFirstTagValue('a')!)
            : null);
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

  // TODO: Implement copyWith (via codegen)
}

class PartialApp extends ParameterizableReplaceablePartialEvent<App>
    with PartialAppMixin {}

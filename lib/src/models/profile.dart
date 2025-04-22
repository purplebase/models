part of models;

class Profile extends ReplaceableModel<Profile> {
  late final HasMany<Note> notes;
  late final BelongsTo<ContactList> contactList;

  Profile.fromMap(super.map, super.ref) : super.fromMap() {
    notes = HasMany(ref, RequestFilter(authors: {event.pubkey}));
    contactList =
        BelongsTo(ref, RequestFilter<ContactList>(authors: {event.pubkey}));
  }

  @override
  Map<String, dynamic> processMetadata() {
    if (event.content.isEmpty) return {};

    final map = jsonDecode(event.content) as Map;
    var name = map['name'] as String?;
    if (name == null || name.isEmpty) {
      name = map['display_name'] as String?;
    }
    if (name == null || name.isEmpty) {
      name = map['displayName'] as String?;
    }

    map['birthday'] = () {
      final year = map['birthdayYear'] as int?;
      final month = map['birthdayMonth'] as int?;
      final day = map['birthdayDay'] as int?;

      if (year != null && month != null && day != null) {
        try {
          return DateTime(year, month, day);
        } catch (e) {
          // Invalid date values
          return null;
        }
      }
      return null;
    }();

    return {
      'name': name,
      'nip05': map['nip05'],
      'pictureUrl': map['picture'],
      'lud16': map['lud16'],
      'about': map['about'],
      'banner': map['banner'],
      'website': map['website'],
      'birthday': map['birthday'],
    }..removeWhere((k, v) => v == null);
  }

  @override
  Map<String, dynamic> transformMap(Map<String, dynamic> map) {
    // As content was processed into metadata, it can be safely removed
    map['content'] = '';
    return super.transformMap(map);
  }

  String get pubkey => event.pubkey;
  String get npub => bech32Encode('npub', pubkey);
  String? get name => event.metadata['name'];
  String? get nip05 => event.metadata['nip05'];
  String? get pictureUrl => event.metadata['picture'];
  String? get lud16 => event.metadata['lud16'];
  String? get about => event.metadata['about'];
  String? get banner => event.metadata['banner'];
  String? get website => event.metadata['website'];
  DateTime? get birthday => event.metadata['birthday'];

  // External identities from NIP-39 as Record (platform, proofUrl)
  Set<(String, String)> get externalIdentities {
    final identities = <(String, String)>{};

    for (final tag in event.getTagSet('i')) {
      if (tag.length >= 3) {
        identities.add((tag[1], tag[2]));
      }
    }

    return identities;
  }

  String get nameOrNpub => name ?? npub;

  PartialProfile copyWith({
    String? name,
    String? nip05,
    String? pictureUrl,
    String? lud16,
    String? about,
    String? banner,
    String? website,
    DateTime? birthday,
    Set<(String, String)>? externalIdentities,
  }) {
    return PartialProfile(
      name: name ?? this.name,
      nip05: nip05 ?? this.nip05,
      pictureUrl: pictureUrl ?? this.pictureUrl,
      lud16: lud16 ?? this.lud16,
      about: about ?? this.about,
      banner: banner ?? this.banner,
      website: website ?? this.website,
      birthday: birthday ?? this.birthday,
      externalIdentities: externalIdentities ?? this.externalIdentities,
    );
  }

  @override
  String toString() {
    return '<Profile>$name [npub: $npub]';
  }

  // Signed-in related functions and providers

  static final _signedInPubkeysProvider = StateProvider<Set<String>>((_) => {});
  // Wrapper so as not to expose the private notifier
  static final signedInPubkeysProvider =
      Provider((ref) => ref.watch(_signedInPubkeysProvider));

  static final _activePubkeyProvider = StateProvider<String?>((_) => null);

  /// Sets this profile to be the currently active one
  void setAsActive() {
    ref.read(_activePubkeyProvider.notifier).state = pubkey;
  }

  /// Notifies with the currently active signed in [Profile],
  /// when set via [setAsActive] and profile is in local storage
  static final signedInProfileProvider = Provider((ref) {
    final activePubkeys = ref.watch(_activePubkeyProvider);
    final pubkeys = ref.watch(Profile.signedInPubkeysProvider);
    if (activePubkeys == null || !pubkeys.contains(activePubkeys)) {
      return null;
    }
    final state =
        ref.watch(query<Profile>(authors: {activePubkeys}, remote: false));
    return state.models.firstOrNull;
  });
}

class PartialProfile extends ReplaceablePartialModel<Profile> {
  PartialProfile({
    this.name,
    this.nip05,
    this.pictureUrl,
    this.lud16,
    this.about,
    this.banner,
    this.website,
    this.birthday,
    this.externalIdentities,
  }) {
    final content = <String, dynamic>{
      'name': name,
      'nip05': nip05,
      'picture': pictureUrl,
      'lud16': lud16,
      'about': about,
      'banner': banner,
      'website': website,
    }..removeWhere((k, v) => v == null);

    // Only add birthday if defined
    if (birthday != null) {
      content['birthday'] = {
        'year': birthday!.year,
        'month': birthday!.month,
        'day': birthday!.day,
      };
    }

    event.content = jsonEncode(content);

    // Add external identity tags (NIP-39)
    if (externalIdentities != null) {
      for (final identity in externalIdentities!) {
        event.addTag('i', [identity.$1, identity.$2]); // Access Record fields
      }
    }
  }

  String? name;
  String? nip05;
  String? pictureUrl;
  String? lud16;
  String? about;
  String? banner;
  String? website;
  DateTime? birthday;
  Set<(String, String)>? externalIdentities;
}

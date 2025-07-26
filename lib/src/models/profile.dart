part of models;

class Profile extends ReplaceableModel<Profile> {
  late final HasMany<Note> notes;
  late final BelongsTo<ContactList> contactList;

  Profile.fromMap(super.map, super.ref) : super.fromMap() {
    notes = HasMany(
      ref,
      RequestFilter<Note>(authors: {event.pubkey}).toRequest(),
    );
    contactList = BelongsTo(
      ref,
      RequestFilter<ContactList>(authors: {event.pubkey}).toRequest(),
    );
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
      'picture': map['picture'],
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
  String get npub => _bech32Encode('npub', pubkey);
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

  /// Load a Profile from a NIP-05 address (user@domain.com)
  static Future<Profile?> fromNip05(String address, Ref ref) async {
    try {
      // Decode NIP-05 to get the pubkey
      final pubkey = await Utils.decodeNip05(address);

      // Query storage for the profile with this pubkey
      final storage = ref.read(storageNotifierProvider.notifier);
      final profiles = await storage.query(
        RequestFilter<Profile>(authors: {pubkey}, limit: 1).toRequest(),
      );

      return profiles.isNotEmpty ? profiles.first : null;
    } catch (e) {
      // Return null if NIP-05 resolution fails
      return null;
    }
  }

  /// Returns the BOLT11 invoice string or null if unable to generate
  /// For zap requests, pass the signed zap request in zapRequest parameter
  Future<String?> getLightningInvoice({
    required int amountSats,
    String? comment,
    Map<String, dynamic>? zapRequest,
  }) async {
    if (lud16 == null) return null;

    try {
      // Parse Lightning address (user@domain.com)
      final parts = lud16!.split('@');
      if (parts.length != 2) return null;

      final username = parts[0];
      final domain = parts[1];

      // Step 1: Get LNURL-pay endpoint from .well-known/lnurlp/
      final client = HttpClient();
      try {
        // Request LNURL-pay info
        final lnurlRequest = await client.getUrl(
          Uri.parse('https://$domain/.well-known/lnurlp/$username'),
        );
        final lnurlResponse = await lnurlRequest.close();

        if (lnurlResponse.statusCode != 200) return null;

        final lnurlBody = await lnurlResponse.transform(utf8.decoder).join();
        final lnurlData = jsonDecode(lnurlBody) as Map<String, dynamic>;

        // Validate LNURL-pay response
        if (lnurlData['tag'] != 'payRequest') return null;

        final callback = lnurlData['callback'] as String?;
        final minSendable = lnurlData['minSendable'] as int?;
        final maxSendable = lnurlData['maxSendable'] as int?;

        if (callback == null || minSendable == null || maxSendable == null) {
          return null;
        }

        // If this is a zap request, validate Nostr zap support (NIP-57)
        if (zapRequest != null) {
          final allowsNostr = lnurlData['allowsNostr'] as bool?;
          final nostrPubkey = lnurlData['nostrPubkey'] as String?;

          if (allowsNostr != true ||
              nostrPubkey == null ||
              nostrPubkey.isEmpty) {
            // Recipient doesn't support Nostr zaps
            throw Exception(
              'Recipient does not support Nostr zaps (missing allowsNostr or nostrPubkey)',
            );
          }

          // Validate nostrPubkey format (should be 64-char hex)
          if (nostrPubkey.length != 64 ||
              !RegExp(r'^[0-9a-fA-F]+$').hasMatch(nostrPubkey)) {
            throw Exception('Invalid nostrPubkey format');
          }
        }

        // Convert sats to millisats for LNURL-pay
        final amountMsat = amountSats * 1000;

        // Check amount limits
        if (amountMsat < minSendable || amountMsat > maxSendable) {
          throw Exception('Amount not between min and max sendable');
        }

        // Handle comment length restrictions
        final commentAllowed = lnurlData['commentAllowed'] as int?;
        if (commentAllowed != null &&
            comment != null &&
            comment.length > commentAllowed) {
          comment = comment.substring(0, commentAllowed);
        }

        // Step 2: Request invoice from callback URL
        final callbackParams = <String, String>{
          ...Uri.parse(callback).queryParameters,
          'amount': amountMsat.toString(),
        };

        if (comment != null && comment.isNotEmpty) {
          callbackParams['comment'] = comment;
        }

        // Add zap request as nostr parameter for NIP-57 compliance
        if (zapRequest != null) {
          callbackParams['nostr'] = jsonEncode(zapRequest);
        }

        final callbackUri = Uri.parse(
          callback,
        ).replace(queryParameters: callbackParams);

        // Debug: Print the URI being called
        print('LNURL Callback URI: $callbackUri');
        if (zapRequest != null) {
          print('Zap request JSON length: ${jsonEncode(zapRequest).length}');
        }

        final invoiceRequest = await client.getUrl(callbackUri);
        // Add proper headers
        invoiceRequest.headers.set('Accept', 'application/json');
        invoiceRequest.headers.set('User-Agent', 'Nostr-Dart-Client/1.0');

        final invoiceResponse = await invoiceRequest.close();

        if (invoiceResponse.statusCode != 200) {
          // Get error details for debugging
          final errorBody = await invoiceResponse
              .transform(utf8.decoder)
              .join();
          print('LNURL Error Response: $errorBody');
          throw Exception(
            'LNURL callback failed (${invoiceResponse.statusCode}): $errorBody',
          );
        }

        final invoiceBody = await invoiceResponse
            .transform(utf8.decoder)
            .join();
        final invoiceData = jsonDecode(invoiceBody) as Map<String, dynamic>;

        // Check for errors
        if (invoiceData['status'] == 'ERROR') return null;

        // Return the BOLT11 invoice
        return invoiceData['pr'] as String?;
      } finally {
        client.close();
      }
    } catch (e) {
      // Return null if any step fails
      return null;
    }
  }

  @override
  String toString() {
    return '<Profile>$name [npub: $npub]';
  }
}

class PartialProfile extends ReplaceablePartialModel<Profile> {
  PartialProfile.fromMap(super.map) : super.fromMap();

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

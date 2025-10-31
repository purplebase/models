part of models;

/// A named collection of apps (Kind 30267) from NIP-51.
///
/// **Encryption Strategy:**
/// - Content is plaintext BEFORE signing
/// - Content is encrypted DURING signing (in prepareForSigning)
/// - Content is always encrypted AFTER signing (locally and on relays)
/// - To read: must explicitly decrypt using signer
///
/// App packs allow users to organize applications into collections
/// like "Developer Tools", "Social Apps", or "Games". Supports both encrypted
/// (private) and public app references.
class AppPack extends ParameterizableReplaceableModel<AppPack>
    with EncryptableModel<AppPack> {
  late final HasMany<App> apps;

  AppPack.fromMap(super.map, super.ref) : super.fromMap() {
    // Only include addressable events that are kind 32267 (App)
    final appIds = event
        .getTagSetValues('a')
        .where((id) => id.startsWith('32267:'))
        .toSet();
    apps = HasMany(ref, Request<App>.fromIds(appIds));
  }

  /// The name of this app pack
  String? get name => event.getFirstTagValue('name');

  /// Get private app IDs (content is encrypted - will fail if not decrypted first)
  List<String> get privateAppIds {
    if (content.isEmpty) return [];
    try {
      final decoded = jsonDecode(content);
      return decoded is List ? decoded.cast<String>() : [];
    } catch (e) {
      return [];
    }
  }

  @override
  String getEncryptionPubkey() {
    // Self-encryption: encrypt to own pubkey
    return event.pubkey;
  }
}

/// Create and manage named app collections.
///
/// Example usage:
/// ```dart
/// // Create a public app pack
/// final appPack = PartialAppPack(
///   name: 'Developer Tools',
///   identifier: 'dev-tools',
/// );
/// appPack.addApp('32267:pubkey:vscode');
///
/// // Create a private app pack with encrypted content
/// final privateApps = PartialAppPack.withEncryptedApps(
///   name: 'Private Apps',
///   identifier: 'private',
///   apps: [
///     ['a', '32267:pubkey:secretapp'],
///   ],
/// );
/// await privateApps.signWith(signer);
/// ```
class PartialAppPack extends ParameterizableReplaceablePartialModel<AppPack>
    with EncryptablePartialModel<AppPack> {
  PartialAppPack.fromMap(super.map) : super.fromMap();

  /// The name of this app pack
  String? get name => event.getFirstTagValue('name');
  set name(String? value) => event.setTagValue('name', value);

  /// The description of this app pack
  String? get description => event.getFirstTagValue('description');
  set description(String? value) => event.setTagValue('description', value);

  /// Public app IDs (addressable event IDs) in this pack - only kind 32267
  Set<String> get publicApps =>
      event.getTagSetValues('a').where((id) => id.startsWith('32267:')).toSet();
  set publicApps(Set<String> value) => event.setTagValues('a', value);
  void addApp(String? addressableId) => event.addTagValue('a', addressableId);
  void removeApp(String? addressableId) =>
      event.removeTagWithValue('a', addressableId);

  /// Raw encrypted content (for advanced use)
  String? get encryptedContent => event.content.isEmpty ? null : event.content;
  set encryptedContent(String? value) => event.content = value ?? '';

  /// Creates a new app pack
  ///
  /// [name] - Display name for this app pack
  /// [identifier] - Unique identifier (auto-generated if not provided)
  /// [description] - Optional description
  /// [publicApps] - Initial set of app IDs to include
  PartialAppPack({
    required String name,
    String? identifier,
    String? description,
    Set<String>? publicApps,
  }) {
    this.name = name;
    event.setTagValue('d', identifier ?? _generateIdentifier());
    if (description != null) this.description = description;
    if (publicApps != null) this.publicApps = publicApps;
  }

  /// Creates an app pack with encrypted (private) apps
  ///
  /// [name] - Display name for this app pack
  /// [identifier] - Unique identifier (auto-generated if not provided)
  /// [description] - Optional description
  /// [apps] - List of app IDs to encrypt (e.g., ['32267:pubkey:id'])
  ///
  /// The apps will be encrypted using NIP-44 when signed.
  PartialAppPack.withEncryptedApps({
    required String name,
    String? identifier,
    String? description,
    required List<String> apps,
  }) {
    this.name = name;
    event.setTagValue('d', identifier ?? _generateIdentifier());
    if (description != null) this.description = description;
    setContent(apps);
  }

  /// Get the current private app IDs (plaintext before signing).
  List<String> get privateAppIds {
    if (content.isEmpty) return [];
    try {
      final decoded = jsonDecode(content);
      return decoded is List ? decoded.cast<String>() : [];
    } catch (e) {
      return [];
    }
  }

  /// Set private app IDs (plaintext until signing, then encrypted).
  void setPrivateAppIds(List<String> appIds) => setContent(appIds);

  /// Add an app ID to the private list.
  void addPrivateAppId(String appId) {
    final current = List<String>.from(privateAppIds);
    if (!current.contains(appId)) {
      current.add(appId);
      setContent(current);
    }
  }

  /// Remove an app ID from the private list.
  void removePrivateAppId(String appId) {
    final current = List<String>.from(privateAppIds);
    if (current.remove(appId)) {
      setContent(current);
    }
  }

  /// Clear all private app IDs.
  void clearPrivateAppIds() => clearContent();

  @override
  String getEncryptionPubkey(Signer signer) => signer.pubkey; // Encrypt to self

  String _generateIdentifier() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}

part of models;

// ======================================================================
// Relay List Models (1xxxx kinds)
// ======================================================================

/// Abstract base for all relay list models.
///
/// Relay lists are replaceable events (1xxxx kinds) that define relay
/// configurations for various purposes. Each concrete class represents
/// a specific use case (social relays, app catalogs, etc.).
abstract class RelayList<E extends RelayList<E>> extends ReplaceableModel<E> {
  RelayList.fromMap(super.map, super.ref) : super.fromMap();

  /// Registry: Label → Kind mapping for relay list types
  static const labels = <String, int>{
    'AppCatalog': 10067,
    // Future relay list labels registered here
  };

  /// All relay URLs in this list
  Set<String> get relays => event.getTagSetValues('r');

  /// Relay URLs marked for reading (or both if no marker specified)
  Set<String> get readRelays {
    return event
        .getTagSet('r')
        .where((tag) => tag.length < 3 || tag[2] != 'write')
        .map((tag) => tag[1])
        .toSet();
  }

  /// Relay URLs marked for writing (or both if no marker specified)
  Set<String> get writeRelays {
    return event
        .getTagSet('r')
        .where((tag) => tag.length < 3 || tag[2] != 'read')
        .map((tag) => tag[1])
        .toSet();
  }

  /// Whether this list has any relays configured
  bool get hasRelays => relays.isNotEmpty;
}

/// Abstract base for all partial relay list models.
abstract class PartialRelayList<E extends RelayList<E>>
    extends ReplaceablePartialModel<E> {
  PartialRelayList();
  PartialRelayList.fromMap(super.map) : super.fromMap();

  /// All relay URLs in this list
  Set<String> get relays => event.getTagSetValues('r');
  set relays(Set<String> value) => event.setTagValues('r', value);

  /// Adds a relay for both reading and writing
  void addRelay(String relayUrl) => event.addTag('r', [relayUrl]);

  /// Adds a relay specifically for writing content
  void addWriteRelay(String relayUrl) =>
      event.addTag('r', [relayUrl, '', 'write']);

  /// Adds a relay specifically for reading content
  void addReadRelay(String relayUrl) =>
      event.addTag('r', [relayUrl, '', 'read']);

  /// Removes a relay from the configuration
  void removeRelay(String relayUrl) {
    event.tags.removeWhere(
      (tag) => tag.length > 1 && tag[0] == 'r' && tag[1] == relayUrl,
    );
  }
}

// ======================================================================
// Concrete Relay List Models
// ======================================================================

/// NIP-65: Social relay list (kind 10002)
///
/// A user's preferred relay configuration for social interactions
/// (reading and writing notes, mentions, replies, etc.).
class SocialRelayList extends RelayList<SocialRelayList> {
  SocialRelayList.fromMap(super.map, super.ref) : super.fromMap();
}

/// Manage your social relay configuration.
class PartialSocialRelayList extends PartialRelayList<SocialRelayList> {
  PartialSocialRelayList.fromMap(super.map) : super.fromMap();

  /// Creates a new social relay list configuration
  PartialSocialRelayList({
    Set<String>? writeRelays,
    Set<String>? readRelays,
    Set<String>? bothRelays,
  }) {
    if (writeRelays != null) {
      for (final relay in writeRelays) {
        addWriteRelay(relay);
      }
    }
    if (readRelays != null) {
      for (final relay in readRelays) {
        addReadRelay(relay);
      }
    }
    if (bothRelays != null) {
      for (final relay in bothRelays) {
        addRelay(relay);
      }
    }
  }
}

/// App catalog relay list (kind 10067)
///
/// Relays specifically for discovering and publishing app catalog entries,
/// such as Zapstore applications.
///
/// **Encryption Strategy:**
/// - Public relays are stored in `r` tags (visible to everyone)
/// - Private relays are stored encrypted in `content` field (NIP-44)
/// - Content is always encrypted AFTER signing (locally and on relays)
/// - To read private relays: must explicitly decrypt using signer
class AppCatalogRelayList extends RelayList<AppCatalogRelayList>
    with EncryptableModel<AppCatalogRelayList> {
  AppCatalogRelayList.fromMap(super.map, super.ref) : super.fromMap();

  @override
  String getEncryptionPubkey() => event.pubkey; // Self-encryption

  /// Private relay URLs (content is encrypted - will fail if not decrypted first)
  ///
  /// Returns empty set if content is empty or cannot be parsed.
  /// To read after loading from storage, must decrypt first using signer.
  Set<String> get privateRelays {
    if (content.isEmpty) return {};
    try {
      final decoded = jsonDecode(content);
      return decoded is List ? decoded.cast<String>().toSet() : {};
    } catch (e) {
      return {};
    }
  }

  /// All relays (public + private, if decrypted)
  Set<String> get allRelays => {...relays, ...privateRelays};
}

/// Manage your app catalog relay configuration.
///
/// Supports both public relays (stored in `r` tags) and private relays
/// (encrypted in `content` field using NIP-44).
///
/// Example usage:
/// ```dart
/// // Create a public-only relay list
/// final relayList = PartialAppCatalogRelayList(
///   relays: {'wss://relay.zapstore.dev'},
/// );
///
/// // Create a relay list with private relays
/// final privateRelays = PartialAppCatalogRelayList.withEncryptedRelays(
///   publicRelays: {'wss://public.relay.com'},
///   privateRelays: {'wss://private.relay.com'},
/// );
/// await privateRelays.signWith(signer);
/// ```
class PartialAppCatalogRelayList extends PartialRelayList<AppCatalogRelayList>
    with EncryptablePartialModel<AppCatalogRelayList> {
  PartialAppCatalogRelayList.fromMap(super.map) : super.fromMap();

  /// Creates a new app catalog relay list configuration
  PartialAppCatalogRelayList({Set<String>? relays}) {
    if (relays != null) {
      for (final relay in relays) {
        addRelay(relay);
      }
    }
  }

  /// Creates a relay list with encrypted (private) relays
  ///
  /// [publicRelays] - Relays visible to everyone (stored in `r` tags)
  /// [privateRelays] - Relays encrypted using NIP-44 (stored in `content`)
  ///
  /// The private relays will be encrypted when signed.
  PartialAppCatalogRelayList.withEncryptedRelays({
    Set<String>? publicRelays,
    required Set<String> privateRelays,
  }) {
    if (publicRelays != null) {
      for (final relay in publicRelays) {
        addRelay(relay);
      }
    }
    setContent(privateRelays.toList());
  }

  @override
  String getEncryptionPubkey(Signer signer) => signer.pubkey; // Self-encryption

  /// Private relay URLs (plaintext before signing, encrypted after)
  Set<String> get privateRelays {
    if (content.isEmpty) return {};
    try {
      final decoded = jsonDecode(content);
      return decoded is List ? decoded.cast<String>().toSet() : {};
    } catch (e) {
      return {};
    }
  }

  /// Set private relay URLs (plaintext until signing, then encrypted)
  void setPrivateRelays(Set<String> relays) => setContent(relays.toList());

  /// Add a relay to the private list
  void addPrivateRelay(String relay) {
    final current = Set<String>.from(privateRelays);
    if (!current.contains(relay)) {
      current.add(relay);
      setContent(current.toList());
    }
  }

  /// Remove a relay from the private list
  void removePrivateRelay(String relay) {
    final current = Set<String>.from(privateRelays);
    if (current.remove(relay)) {
      setContent(current.toList());
    }
  }

  /// Clear all private relays
  void clearPrivateRelays() => clearContent();
}


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
class AppCatalogRelayList extends RelayList<AppCatalogRelayList> {
  AppCatalogRelayList.fromMap(super.map, super.ref) : super.fromMap();
}

/// Manage your app catalog relay configuration.
class PartialAppCatalogRelayList extends PartialRelayList<AppCatalogRelayList> {
  PartialAppCatalogRelayList.fromMap(super.map) : super.fromMap();

  /// Creates a new app catalog relay list configuration
  PartialAppCatalogRelayList({Set<String>? relays}) {
    if (relays != null) {
      for (final relay in relays) {
        addRelay(relay);
      }
    }
  }
}


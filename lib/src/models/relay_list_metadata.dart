part of models;

// ======================================================================
// NIP-65: Relay List Metadata
// ======================================================================

/// A user's preferred relay configuration for reading and writing content.
///
/// Relay lists help the network understand where to find a user's content
/// and where to send them mentions. Users typically maintain 2-4 relays
/// for optimal performance and redundancy.
class RelayListMetadata extends ReplaceableModel<RelayListMetadata> {
  RelayListMetadata.fromMap(super.map, super.ref) : super.fromMap();

  /// All relay URLs configured by this user
  Set<String> get allRelayUrls => event.getTagSetValues('r');

  /// Relays where the user publishes content
  Set<String> get writeRelays {
    return event
        .getTagSet('r')
        .where((tag) => tag.length < 3 || tag[2] != 'read')
        .map((tag) => tag[1])
        .toSet();
  }

  /// Relays where the user reads mentions and replies
  Set<String> get readRelays {
    return event
        .getTagSet('r')
        .where((tag) => tag.length < 3 || tag[2] != 'write')
        .map((tag) => tag[1])
        .toSet();
  }

  /// Whether this user has configured any relays
  bool get hasRelays => allRelayUrls.isNotEmpty;
}

/// Manage your relay configuration for optimal network performance.
///
/// Example usage:
/// ```dart
/// final relayList = await PartialRelayListMetadata()
///   ..addWriteRelay('wss://relay.damus.io')
///   ..addReadRelay('wss://nos.lol')
///   ..addRelay('wss://relay.snort.social'); // both read and write
/// await relayList.signWith(signer);
/// ```
class PartialRelayListMetadata
    extends ReplaceablePartialModel<RelayListMetadata> {
  PartialRelayListMetadata.fromMap(super.map) : super.fromMap();

  /// All relay URLs configured by this user
  Set<String> get allRelayUrls => event.getTagSetValues('r');

  /// Sets all relay URLs (clears existing configuration)
  set allRelayUrls(Set<String> value) => event.setTagValues('r', value);

  /// Adds a relay for both reading and writing
  void addRelay(String relayUrl) => event.addTag('r', [relayUrl]);

  /// Adds a relay specifically for writing content
  void addWriteRelay(String relayUrl) =>
      event.addTag('r', [relayUrl, '', 'write']);

  /// Adds a relay specifically for reading mentions
  void addReadRelay(String relayUrl) =>
      event.addTag('r', [relayUrl, '', 'read']);

  /// Removes a relay from the configuration
  void removeRelay(String relayUrl) {
    event.tags.removeWhere(
      (tag) => tag.length > 1 && tag[0] == 'r' && tag[1] == relayUrl,
    );
  }

  /// Creates a new relay list configuration
  PartialRelayListMetadata({
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

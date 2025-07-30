part of models;

/// A bunker authorization event (kind 24133) for NIP-46 remote signing.
///
/// Bunker authorization events handle permissions for remote signing
/// operations through the NIP-46 protocol (Nostr Connect).
class BunkerAuthorization extends EphemeralModel<BunkerAuthorization> {
  BunkerAuthorization.fromMap(super.map, super.ref) : super.fromMap();

  /// Authorization content (permission details)
  String get content => event.content;

  /// Authorized public key for remote signing
  String get authorizedPubkey => event.getFirstTagValue('p')!;
}

/// Create and sign new bunker authorization events.
class PartialBunkerAuthorization
    extends EphemeralPartialModel<BunkerAuthorization> {
  PartialBunkerAuthorization.fromMap(super.map) : super.fromMap();

  /// Creates a new bunker authorization event
  PartialBunkerAuthorization();

  /// Sets the authorization content
  set content(String value) => event.content = value;

  /// Sets the authorized public key
  set pubkey(String value) => event.setTagValue('p', value);
}

/// Types of bunker operations that can be authorized
enum BunkerAuthorizationType {
  /// Get/read operations
  get,

  /// Upload operations
  upload,

  /// List operations
  list,

  /// Delete operations
  delete,
}

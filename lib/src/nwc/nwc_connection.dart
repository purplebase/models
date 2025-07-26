part of models;

/// A Nostr Wallet Connect (NWC) connection for interacting with Lightning wallets.
///
/// NWC allows applications to connect to Lightning wallets over Nostr for
/// making payments, checking balances, and other wallet operations.
///
/// Example usage:
/// ```dart
/// final connection = NwcConnection.fromUri(connectionString);
/// print(connection.walletPubkey); // Wallet service public key
/// print(connection.relay); // Relay URL
/// ```
class NwcConnection {
  /// The wallet service's public key
  final String walletPubkey;

  /// The client's secret key for this connection (hex encoded)
  final String secret;

  /// The relay URL where wallet service listens
  final String relay;

  /// Optional Lightning address for the wallet
  final String? lud16;

  /// Optional budget limits and permissions
  final NwcConnectionLimits? limits;

  /// When this connection was created
  final DateTime createdAt;

  /// Optional expiration time for this connection
  final DateTime? expiresAt;

  const NwcConnection({
    required this.walletPubkey,
    required this.secret,
    required this.relay,
    this.lud16,
    this.limits,
    required this.createdAt,
    this.expiresAt,
  });

  /// The client's public key derived from the secret
  String get clientPubkey => Utils.derivePublicKey(secret);

  /// Derive the client's private key from the connection secret
  /// This follows NIP-47 specification for key derivation
  String get clientPrivateKey {
    // The secret is already a 64-character hex string
    // In NIP-47, this is the client's private key directly
    return secret;
  }

  /// Check if this connection has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Convert to storage map
  Map<String, dynamic> toMap() {
    return {
      'walletPubkey': walletPubkey,
      'secret': secret,
      'relay': relay,
      if (lud16 != null) 'lud16': lud16,
      if (limits != null) 'limits': limits!.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      if (expiresAt != null) 'expiresAt': expiresAt!.millisecondsSinceEpoch,
    };
  }

  /// Parse a NWC URI into a connection object
  factory NwcConnection.fromUri(String uri) {
    // Expected format: nostr+walletconnect://pubkey?relay=...&secret=...&lud16=...
    if (!uri.startsWith('nostr+walletconnect://')) {
      throw ArgumentError(
        'Invalid NWC URI: must start with nostr+walletconnect://',
      );
    }

    // Remove the protocol
    final withoutProtocol = uri.substring('nostr+walletconnect://'.length);

    // Split on '?' to separate pubkey from query parameters
    final parts = withoutProtocol.split('?');
    if (parts.length != 2) {
      throw ArgumentError('Invalid NWC URI: missing query parameters');
    }

    final walletPubkey = parts[0];
    if (walletPubkey.length != 64) {
      throw ArgumentError(
        'Invalid NWC URI: wallet pubkey must be 64 hex characters',
      );
    }

    // Parse query parameters
    final queryParams = Uri.splitQueryString(parts[1]);

    final relay = queryParams['relay'];
    if (relay == null) {
      throw ArgumentError('Invalid NWC URI: missing required relay parameter');
    }

    final secret = queryParams['secret'];
    if (secret == null) {
      throw ArgumentError('Invalid NWC URI: missing required secret parameter');
    }
    if (secret.length != 64) {
      throw ArgumentError('Invalid NWC URI: secret must be 64 hex characters');
    }

    final lud16 = queryParams['lud16'];

    return NwcConnection(
      walletPubkey: walletPubkey,
      secret: secret,
      relay: relay,
      lud16: lud16,
      createdAt: DateTime.now(),
    );
  }

  /// Generate NWC URI for this connection
  String toUri() {
    final queryParams = <String, String>{
      'relay': relay,
      'secret': secret,
      if (lud16 != null) 'lud16': lud16!,
    };

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    return 'nostr+walletconnect://$walletPubkey?$queryString';
  }

  @override
  String toString() {
    return '_NwcConnection(walletPubkey: ${walletPubkey.substring(0, 8)}..., relay: $relay)';
  }
}

/// Connection limits and permissions for NWC connections
class NwcConnectionLimits {
  /// Maximum amount in sats that can be spent per renewal period
  final int? maxAmount;

  /// Budget renewal period
  final NwcBudgetRenewal budgetRenewal;

  /// Allowed request methods
  final Set<String> allowedMethods;

  const NwcConnectionLimits({
    this.maxAmount,
    this.budgetRenewal = NwcBudgetRenewal.never,
    this.allowedMethods = const {'pay_invoice'},
  });

  Map<String, dynamic> toMap() {
    return {
      if (maxAmount != null) 'maxAmount': maxAmount,
      'budgetRenewal': budgetRenewal.name,
      'allowedMethods': allowedMethods.toList(),
    };
  }

  factory NwcConnectionLimits.fromMap(Map<String, dynamic> map) {
    return NwcConnectionLimits(
      maxAmount: map['maxAmount'] as int?,
      budgetRenewal: NwcBudgetRenewal.values.firstWhere(
        (e) => e.name == map['budgetRenewal'],
        orElse: () => NwcBudgetRenewal.never,
      ),
      allowedMethods: (map['allowedMethods'] as List<dynamic>)
          .cast<String>()
          .toSet(),
    );
  }
}

/// Budget renewal periods for NWC connections
enum NwcBudgetRenewal { never, daily, weekly, monthly, yearly }

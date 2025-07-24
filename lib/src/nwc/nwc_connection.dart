part of models;

/// Represents a connection to a Nostr Wallet Connect service
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

  /// Create from storage map
  factory NwcConnection.fromMap(Map<String, dynamic> map) {
    return NwcConnection(
      walletPubkey: map['walletPubkey'] as String,
      secret: map['secret'] as String,
      relay: map['relay'] as String,
      lud16: map['lud16'] as String?,
      limits: map['limits'] != null
          ? NwcConnectionLimits.fromMap(map['limits'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      expiresAt: map['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int)
          : null,
    );
  }

  /// Create connection from NWC URI
  factory NwcConnection.fromUri(String uri) {
    return NwcUriParser.parse(uri);
  }

  /// Generate NWC URI for this connection
  String toUri() {
    return NwcUriParser.generate(this);
  }

  @override
  String toString() {
    return 'NwcConnection(walletPubkey: ${walletPubkey.substring(0, 8)}..., relay: $relay)';
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

/// Parser for NWC URIs following NIP-47 specification
class NwcUriParser {
  /// Parse a NWC URI into a connection object
  static NwcConnection parse(String uri) {
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

  /// Generate a NWC URI from a connection object
  static String generate(NwcConnection connection) {
    final queryParams = <String, String>{
      'relay': connection.relay,
      'secret': connection.secret,
      if (connection.lud16 != null) 'lud16': connection.lud16!,
    };

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    return 'nostr+walletconnect://${connection.walletPubkey}?$queryString';
  }
}

/// Riverpod provider for NWC connection manager
/// Provides a singleton instance of NwcConnectionManager for the app
final nwcConnectionManagerProvider = Provider<NwcConnectionManager>((ref) {
  final signer = ref.watch(Signer.activeSignerProvider);
  if (signer == null) {
    throw Exception('No active signer available for NWC connection manager');
  }
  return NwcConnectionManager(ref, signer: signer);
});

/// Riverpod provider for NWC connection manager with custom signer
/// Use this when you need a specific signer instance
final nwcConnectionManagerWithSignerProvider =
    Provider.family<NwcConnectionManager, Signer>((ref, signer) {
      return NwcConnectionManager(ref, signer: signer);
    });

/// Manager for NWC connections with secure storage
/// Uses CustomData with NIP-44 encryption to securely store sensitive NWC data
class NwcConnectionManager {
  static const String _connectionPrefix = 'nwc_connection_';
  static const String _activeConnectionKey = 'nwc_active_connection';
  static const String _secretPrefix = 'nwc_secret_';

  final Ref _ref;
  final Signer _signer;
  late final StorageNotifier _storage;

  NwcConnectionManager(Ref ref, {Signer? signer})
    : _ref = ref,
      _signer = signer ?? ref.read(Signer.activeSignerProvider)! {
    _storage = _ref.read(storageNotifierProvider.notifier);
  }

  /// Store a NWC connection securely using NIP-44 encryption
  Future<void> storeConnection(
    String connectionId,
    NwcConnection connection,
  ) async {
    final identifier = _connectionPrefix + connectionId;
    final jsonData = jsonEncode(connection.toMap());

    // Encrypt the connection data using NIP-44 with our own pubkey
    final encryptedData = await _signer.nip44Encrypt(jsonData, _signer.pubkey);

    // Create CustomData with encrypted content
    final partialData = PartialCustomData(
      identifier: identifier,
      content: encryptedData,
    );

    final signedData = (await _signer.sign([partialData])).first;
    await _storage.save({signedData});
  }

  /// Retrieve a NWC connection by ID
  Future<NwcConnection?> getConnection(String connectionId) async {
    final identifier = _connectionPrefix + connectionId;

    try {
      final customDataList = await _storage.query(
        RequestFilter<CustomData>(
          authors: {_signer.pubkey},
          tags: {
            '#d': {identifier},
          },
        ).toRequest(),
      );

      if (customDataList.isEmpty) return null;

      final customData = customDataList.first;

      // If content is empty, treat as deleted
      if (customData.content.isEmpty) return null;

      final decryptedJson = await _signer.nip44Decrypt(
        customData.content,
        _signer.pubkey,
      );
      final map = jsonDecode(decryptedJson) as Map<String, dynamic>;

      return NwcConnection.fromMap(map);
    } catch (e) {
      // If decryption fails, remove the corrupted entry
      await removeConnection(connectionId);
      return null;
    }
  }

  /// Remove a NWC connection
  Future<void> removeConnection(String connectionId) async {
    final identifier = _connectionPrefix + connectionId;

    // Create empty CustomData to "delete" the connection
    final partialData = PartialCustomData(identifier: identifier, content: '');
    final signedData = (await _signer.sign([partialData])).first;
    await _storage.save({signedData});
  }

  /// Get all stored connection IDs
  Future<Set<String>> getAllConnectionIds() async {
    final allCustomData = await _storage.query(
      RequestFilter<CustomData>(authors: {_signer.pubkey}).toRequest(),
    );

    return allCustomData
        .where((data) => data.identifier.startsWith(_connectionPrefix))
        .where(
          (data) => data.content.isNotEmpty,
        ) // Filter out deleted connections
        .map((data) => data.identifier.substring(_connectionPrefix.length))
        .toSet();
  }

  /// Get all stored connections
  Future<Map<String, NwcConnection>> getAllConnections() async {
    final connectionIds = await getAllConnectionIds();
    final connections = <String, NwcConnection>{};

    for (final id in connectionIds) {
      final connection = await getConnection(id);
      if (connection != null) {
        connections[id] = connection;
      }
    }

    return connections;
  }

  /// Set the active connection ID
  Future<void> setActiveConnection(String? connectionId) async {
    if (connectionId == null) {
      // Create empty CustomData to "delete" the active connection
      final partialData = PartialCustomData(
        identifier: _activeConnectionKey,
        content: '',
      );
      final signedData = (await _signer.sign([partialData])).first;
      await _storage.save({signedData});
    } else {
      final encryptedData = await _signer.nip44Encrypt(
        connectionId,
        _signer.pubkey,
      );
      final partialData = PartialCustomData(
        identifier: _activeConnectionKey,
        content: encryptedData,
      );
      final signedData = (await _signer.sign([partialData])).first;
      await _storage.save({signedData});
    }
  }

  /// Get the active connection ID
  Future<String?> getActiveConnectionId() async {
    try {
      final customDataList = await _storage.query(
        RequestFilter<CustomData>(
          authors: {_signer.pubkey},
          tags: {
            '#d': {_activeConnectionKey},
          },
        ).toRequest(),
      );

      if (customDataList.isEmpty) return null;

      final customData = customDataList.first;
      if (customData.content.isEmpty) return null;

      return await _signer.nip44Decrypt(customData.content, _signer.pubkey);
    } catch (e) {
      return null;
    }
  }

  /// Get the active connection
  Future<NwcConnection?> getActiveConnection() async {
    final activeId = await getActiveConnectionId();
    if (activeId == null) return null;
    return await getConnection(activeId);
  }

  /// Clear all NWC data (creates deletion markers)
  Future<void> clearAll() async {
    final connectionIds = await getAllConnectionIds();

    for (final id in connectionIds) {
      await removeConnection(id);
    }

    await setActiveConnection(null);
  }

  /// Store a standalone secret by key using NIP-44 encryption
  Future<void> storeSecret(String key, String secret) async {
    final identifier = _secretPrefix + key;
    final encryptedData = await _signer.nip44Encrypt(secret, _signer.pubkey);

    final partialData = PartialCustomData(
      identifier: identifier,
      content: encryptedData,
    );

    final signedData = (await _signer.sign([partialData])).first;
    await _storage.save({signedData});
  }

  /// Retrieve a standalone secret by key
  Future<String?> getSecret(String key) async {
    final identifier = _secretPrefix + key;

    try {
      final customDataList = await _storage.query(
        RequestFilter<CustomData>(
          authors: {_signer.pubkey},
          tags: {
            '#d': {identifier},
          },
        ).toRequest(),
      );

      if (customDataList.isEmpty) return null;

      final customData = customDataList.first;
      return await _signer.nip44Decrypt(customData.content, _signer.pubkey);
    } catch (e) {
      return null;
    }
  }

  /// Remove a standalone secret by key
  Future<void> removeSecret(String key) async {
    final identifier = _secretPrefix + key;

    // Create empty CustomData to "delete" the secret
    final partialData = PartialCustomData(identifier: identifier, content: '');
    final signedData = (await _signer.sign([partialData])).first;
    await _storage.save({signedData});
  }
}

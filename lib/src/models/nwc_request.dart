part of models;

/// NWC Request Event (NIP-47 kind 23194)
/// Encrypted request from client to wallet service for wallet operations
class NwcRequest extends EphemeralModel<NwcRequest> {
  NwcRequest.fromMap(super.map, super.ref) : super.fromMap();

  /// The wallet service public key this request is directed to
  String get walletPubkey {
    final pTag = event.getFirstTagValue('p');
    if (pTag == null) {
      throw Exception('NWC request missing wallet pubkey (p tag)');
    }
    return pTag;
  }

  /// Optional expiration timestamp for this request
  DateTime? get expiration {
    final expirationTag = event.getFirstTagValue('expiration');
    if (expirationTag == null) return null;
    final timestamp = int.tryParse(expirationTag);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  /// Check if this request has expired
  bool get isExpired {
    final exp = expiration;
    if (exp == null) return false;
    return DateTime.now().isAfter(exp);
  }

  /// Encrypted content (decrypt with NIP-04 to get actual command)
  String get encryptedContent => event.content;

  /// Decrypt the content using the provided signer
  /// Returns a map with 'method' and 'params' fields
  Future<Map<String, dynamic>> decryptContent(Signer signer) async {
    final decryptedJson = await signer.nip04Decrypt(
      event.content,
      walletPubkey,
    );
    final decoded = jsonDecode(decryptedJson) as Map<String, dynamic>;

    // Validate required fields
    if (!decoded.containsKey('method')) {
      throw Exception('NWC request missing required "method" field');
    }

    return decoded;
  }

  /// Get the command method from decrypted content (requires signer)
  Future<String> getMethod(Signer signer) async {
    final content = await decryptContent(signer);
    return content['method'] as String;
  }

  /// Get the command parameters from decrypted content (requires signer)
  Future<Map<String, dynamic>?> getParams(Signer signer) async {
    final content = await decryptContent(signer);
    return content['params'] as Map<String, dynamic>?;
  }
}

/// Partial model for creating NwcRequest events
class PartialNwcRequest extends EphemeralPartialModel<NwcRequest> {
  PartialNwcRequest.fromMap(super.map) : super.fromMap();

  PartialNwcRequest({
    required String walletPubkey,
    required String method,
    Map<String, dynamic>? params,
    DateTime? expiration,
    DateTime? createdAt,
  }) {
    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    // Add wallet pubkey as p tag
    event.setTagValue('p', walletPubkey);

    // Add expiration if provided
    if (expiration != null) {
      final timestamp = expiration.millisecondsSinceEpoch ~/ 1000;
      event.setTagValue('expiration', timestamp.toString());
    }

    // Create the command JSON
    final command = <String, dynamic>{
      'method': method,
      if (params != null) 'params': params,
    };

    // Content will be encrypted when signing
    event.content = jsonEncode(command);
  }

  /// Create a request for pay_invoice command
  PartialNwcRequest.payInvoice({
    required String walletPubkey,
    required String invoice,
    int? amount,
    DateTime? expiration,
    DateTime? createdAt,
  }) : this(
         walletPubkey: walletPubkey,
         method: NwcInfo.payInvoice,
         params: {'invoice': invoice, if (amount != null) 'amount': amount},
         expiration: expiration,
         createdAt: createdAt,
       );

  /// Create a request for get_balance command
  PartialNwcRequest.getBalance({
    required String walletPubkey,
    DateTime? expiration,
    DateTime? createdAt,
  }) : this(
         walletPubkey: walletPubkey,
         method: NwcInfo.getBalance,
         params: {},
         expiration: expiration,
         createdAt: createdAt,
       );

  /// Create a request for make_invoice command
  PartialNwcRequest.makeInvoice({
    required String walletPubkey,
    required int amount,
    String? description,
    String? descriptionHash,
    int? expiry,
    DateTime? expiration,
    DateTime? createdAt,
  }) : this(
         walletPubkey: walletPubkey,
         method: NwcInfo.makeInvoice,
         params: {
           'amount': amount,
           if (description != null) 'description': description,
           if (descriptionHash != null) 'description_hash': descriptionHash,
           if (expiry != null) 'expiry': expiry,
         },
         expiration: expiration,
         createdAt: createdAt,
       );

  /// Create a request for get_info command
  PartialNwcRequest.getInfo({
    required String walletPubkey,
    DateTime? expiration,
    DateTime? createdAt,
  }) : this(
         walletPubkey: walletPubkey,
         method: NwcInfo.getInfo,
         params: {},
         expiration: expiration,
         createdAt: createdAt,
       );
}

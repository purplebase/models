part of models;

/// NWC Response Event (NIP-47 kind 23195)
/// Encrypted response from wallet service to client with command results
class NwcResponse extends EphemeralModel<NwcResponse> {
  NwcResponse.fromMap(super.map, super.ref) : super.fromMap();

  /// The client public key this response is directed to
  String get clientPubkey {
    final pTag = event.getFirstTagValue('p');
    if (pTag == null) {
      throw Exception('NWC response missing client pubkey (p tag)');
    }
    return pTag;
  }

  /// The request event ID this response is replying to
  String? get requestEventId {
    return event.getFirstTagValue('e');
  }

  /// Encrypted content (decrypt with NIP-04 to get actual response)
  String get encryptedContent => event.content;

  /// Decrypt the content using the provided signer
  /// Returns a map with 'result_type', 'result', and possibly 'error' fields
  Future<Map<String, dynamic>> decryptContent(Signer signer) async {
    // The response is encrypted FROM the wallet TO the client using NIP-04
    // So we decrypt using the wallet's pubkey as the sender
    final decryptedJson = await signer.nip04Decrypt(
      event.content,
      event.pubkey, // wallet's pubkey (sender of the response)
    );

    if (decryptedJson.trim().isEmpty) {
      throw Exception('Decrypted content is empty');
    }

    final decoded = jsonDecode(decryptedJson) as Map<String, dynamic>;

    // Validate required fields
    if (!decoded.containsKey('result_type')) {
      throw Exception('NWC response missing required "result_type" field');
    }

    return decoded;
  }

  /// Get the result type from decrypted content (requires signer)
  Future<String> getResultType(Signer signer) async {
    final content = await decryptContent(signer);
    return content['result_type'] as String;
  }

  /// Get the result data from decrypted content (requires signer)
  /// Returns null if there was an error
  Future<Map<String, dynamic>?> getResult(Signer signer) async {
    final content = await decryptContent(signer);
    return content['result'] as Map<String, dynamic>?;
  }

  /// Get error information from decrypted content (requires signer)
  /// Returns null if there was no error
  Future<NwcError?> getError(Signer signer) async {
    final content = await decryptContent(signer);
    final errorData = content['error'] as Map<String, dynamic>?;
    if (errorData == null) return null;
    return NwcError.fromMap(errorData);
  }

  /// Check if this response contains an error (requires signer)
  Future<bool> hasError(Signer signer) async {
    final error = await getError(signer);
    return error != null;
  }
}

/// NWC Error information
class NwcError {
  final String code;
  final String message;

  const NwcError({required this.code, required this.message});

  factory NwcError.fromMap(Map<String, dynamic> map) {
    return NwcError(
      code: map['code'] as String,
      message: map['message'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'code': code, 'message': message};
  }

  /// Common NWC error codes
  static const String rateLimited = 'RATE_LIMITED';
  static const String notImplemented = 'NOT_IMPLEMENTED';
  static const String insufficientBalance = 'INSUFFICIENT_BALANCE';
  static const String quotaExceeded = 'QUOTA_EXCEEDED';
  static const String restricted = 'RESTRICTED';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String internal = 'INTERNAL';
  static const String other = 'OTHER';
  static const String paymentFailed = 'PAYMENT_FAILED';
  static const String notFound = 'NOT_FOUND';

  @override
  String toString() => 'NwcError(code: $code, message: $message)';
}

/// Partial model for creating NwcResponse events
class PartialNwcResponse extends EphemeralPartialModel<NwcResponse> {
  PartialNwcResponse.fromMap(super.map) : super.fromMap();

  PartialNwcResponse({
    required String clientPubkey,
    required String resultType,
    Map<String, dynamic>? result,
    NwcError? error,
    String? requestEventId,
    DateTime? createdAt,
  }) {
    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    // Add client pubkey as p tag
    event.setTagValue('p', clientPubkey);

    // Add request event ID if provided
    if (requestEventId != null) {
      event.setTagValue('e', requestEventId);
    }

    // Create the response JSON
    final response = <String, dynamic>{
      'result_type': resultType,
      if (error != null) 'error': error.toMap() else 'error': null,
      if (result != null) 'result': result else 'result': null,
    };

    // Content will be encrypted when signing
    event.content = jsonEncode(response);
  }

  /// Create a successful response
  PartialNwcResponse.success({
    required String clientPubkey,
    required String resultType,
    required Map<String, dynamic> result,
    String? requestEventId,
    DateTime? createdAt,
  }) : this(
         clientPubkey: clientPubkey,
         resultType: resultType,
         result: result,
         error: null,
         requestEventId: requestEventId,
         createdAt: createdAt,
       );

  /// Create an error response
  PartialNwcResponse.error({
    required String clientPubkey,
    required String resultType,
    required NwcError error,
    String? requestEventId,
    DateTime? createdAt,
  }) : this(
         clientPubkey: clientPubkey,
         resultType: resultType,
         result: null,
         error: error,
         requestEventId: requestEventId,
         createdAt: createdAt,
       );

  /// Create a pay_invoice success response
  PartialNwcResponse.payInvoiceSuccess({
    required String clientPubkey,
    required String preimage,
    int? feesPaid,
    String? requestEventId,
    DateTime? createdAt,
  }) : this.success(
         clientPubkey: clientPubkey,
         resultType: NwcInfo.payInvoice,
         result: {
           'preimage': preimage,
           if (feesPaid != null) 'fees_paid': feesPaid,
         },
         requestEventId: requestEventId,
         createdAt: createdAt,
       );

  /// Create a get_balance success response
  PartialNwcResponse.getBalanceSuccess({
    required String clientPubkey,
    required int balance,
    String? requestEventId,
    DateTime? createdAt,
  }) : this.success(
         clientPubkey: clientPubkey,
         resultType: NwcInfo.getBalance,
         result: {'balance': balance},
         requestEventId: requestEventId,
         createdAt: createdAt,
       );

  /// Create a make_invoice success response
  PartialNwcResponse.makeInvoiceSuccess({
    required String clientPubkey,
    required String invoice,
    required String paymentHash,
    required int amount,
    String? description,
    int? createdAtTimestamp,
    int? expiresAtTimestamp,
    Map<String, dynamic>? metadata,
    String? requestEventId,
    DateTime? createdAt,
  }) : this.success(
         clientPubkey: clientPubkey,
         resultType: NwcInfo.makeInvoice,
         result: {
           'type': 'incoming',
           'invoice': invoice,
           'payment_hash': paymentHash,
           'amount': amount,
           if (description != null) 'description': description,
           if (createdAtTimestamp != null) 'created_at': createdAtTimestamp,
           if (expiresAtTimestamp != null) 'expires_at': expiresAtTimestamp,
           if (metadata != null) 'metadata': metadata,
         },
         requestEventId: requestEventId,
         createdAt: createdAt,
       );
}

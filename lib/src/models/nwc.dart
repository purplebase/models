part of models;

/// NWC Info Event (NIP-47 kind 13194)
/// Published by wallet service to indicate which capabilities it supports
class NwcInfo extends ReplaceableModel<NwcInfo> {
  NwcInfo.fromMap(super.map, super.ref) : super.fromMap();

  /// List of supported NWC methods (space-separated in content)
  List<String> get supportedMethods {
    if (event.content.isEmpty) return [];
    return event.content
        .split(' ')
        .where((method) => method.isNotEmpty)
        .toList();
  }

  /// List of supported notification types from notifications tag
  List<String> get supportedNotifications {
    final notificationsTag = event.getFirstTagValue('notifications');
    if (notificationsTag == null) return [];
    return notificationsTag
        .split(' ')
        .where((notification) => notification.isNotEmpty)
        .toList();
  }

  /// Check if a specific method is supported
  bool supportsMethod(String method) {
    return supportedMethods.contains(method);
  }

  /// Check if a specific notification type is supported
  bool supportsNotification(String notification) {
    return supportedNotifications.contains(notification);
  }

  /// Common NWC methods
  static const String payInvoice = 'pay_invoice';
  static const String multiPayInvoice = 'multi_pay_invoice';
  static const String payKeysend = 'pay_keysend';
  static const String multiPayKeysend = 'multi_pay_keysend';
  static const String makeInvoice = 'make_invoice';
  static const String lookupInvoice = 'lookup_invoice';
  static const String listTransactions = 'list_transactions';
  static const String getBalance = 'get_balance';
  static const String getInfo = 'get_info';

  /// Common notification types
  static const String paymentReceived = 'payment_received';
  static const String paymentSent = 'payment_sent';
}

/// Generated partial model mixin for NwcInfo
mixin PartialNwcInfoMixin on ReplaceablePartialModel<NwcInfo> {
  /// Set supported methods (will be joined with spaces in content)
  set supportedMethods(List<String> methods) {
    event.content = methods.join(' ');
  }

  /// Set supported notifications (will be added as notifications tag)
  set supportedNotifications(List<String> notifications) => event.setTagValue(
    'notifications',
    notifications.isNotEmpty ? notifications.join(' ') : null,
  );
}

/// Partial model for creating NwcInfo events
/// Create and sign new NWC info events.
///
/// Example usage:
/// ```dart
/// final nwcInfo = await PartialNwcInfo(supportedMethods: ['pay_invoice', 'get_balance']).signWith(signer);
/// ```
class PartialNwcInfo extends ReplaceablePartialModel<NwcInfo>
    with PartialNwcInfoMixin {
  PartialNwcInfo.fromMap(super.map) : super.fromMap();

  PartialNwcInfo({
    List<String> supportedMethods = const [],
    List<String> supportedNotifications = const [],
    DateTime? createdAt,
  }) {
    if (createdAt != null) {
      event.createdAt = createdAt;
    }
    this.supportedMethods = supportedMethods;
    this.supportedNotifications = supportedNotifications;
  }
}

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
/// Create and sign new NWC response events.
///
/// Example usage:
/// ```dart
/// final nwcResponse = await PartialNwcResponse(clientPubkey: clientKey, resultType: 'get_balance').signWith(signer);
/// ```
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

/// NWC Notification Event (NIP-47 kind 23196)
/// Encrypted notification from wallet service to client about wallet events
class NwcNotification extends EphemeralModel<NwcNotification> {
  NwcNotification.fromMap(super.map, super.ref) : super.fromMap();

  /// The client public key this notification is directed to
  String get clientPubkey {
    final pTag = event.getFirstTagValue('p');
    if (pTag == null) {
      throw Exception('NWC notification missing client pubkey (p tag)');
    }
    return pTag;
  }

  /// Encrypted content (decrypt with NIP-04 to get actual notification)
  String get encryptedContent => event.content;

  /// Decrypt the content using the provided signer
  /// Returns a map with 'notification_type' and 'notification' fields
  Future<Map<String, dynamic>> decryptContent(Signer signer) async {
    final decryptedJson = await signer.nip04Decrypt(
      event.content,
      clientPubkey,
    );
    final decoded = jsonDecode(decryptedJson) as Map<String, dynamic>;

    // Validate required fields
    if (!decoded.containsKey('notification_type')) {
      throw Exception(
        'NWC notification missing required "notification_type" field',
      );
    }

    return decoded;
  }

  /// Get the notification type from decrypted content (requires signer)
  Future<String> getNotificationType(Signer signer) async {
    final content = await decryptContent(signer);
    return content['notification_type'] as String;
  }

  /// Get the notification data from decrypted content (requires signer)
  Future<Map<String, dynamic>?> getNotification(Signer signer) async {
    final content = await decryptContent(signer);
    return content['notification'] as Map<String, dynamic>?;
  }

  /// Check if this is a payment received notification (requires signer)
  Future<bool> isPaymentReceived(Signer signer) async {
    final type = await getNotificationType(signer);
    return type == NwcInfo.paymentReceived;
  }

  /// Check if this is a payment sent notification (requires signer)
  Future<bool> isPaymentSent(Signer signer) async {
    final type = await getNotificationType(signer);
    return type == NwcInfo.paymentSent;
  }
}

/// Partial model for creating NwcNotification events
/// Create and sign new NWC notification events.
///
/// Example usage:
/// ```dart
/// final notification = await PartialNwcNotification(clientPubkey: clientKey, notificationType: 'payment_received', notification: {}).signWith(signer);
/// ```
class PartialNwcNotification extends EphemeralPartialModel<NwcNotification> {
  PartialNwcNotification.fromMap(super.map) : super.fromMap();

  PartialNwcNotification({
    required String clientPubkey,
    required String notificationType,
    required Map<String, dynamic> notification,
    DateTime? createdAt,
  }) {
    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    // Add client pubkey as p tag
    event.setTagValue('p', clientPubkey);

    // Create the notification JSON
    final notificationData = <String, dynamic>{
      'notification_type': notificationType,
      'notification': notification,
    };

    // Content will be encrypted when signing
    event.content = jsonEncode(notificationData);
  }

  /// Create a payment received notification
  PartialNwcNotification.paymentReceived({
    required String clientPubkey,
    required String invoice,
    required String preimage,
    required String paymentHash,
    required int amount,
    String? description,
    String? descriptionHash,
    int? feesPaid,
    int? createdAtTimestamp,
    int? expiresAtTimestamp,
    int? settledAtTimestamp,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) : this(
         clientPubkey: clientPubkey,
         notificationType: NwcInfo.paymentReceived,
         notification: {
           'type': 'incoming',
           'invoice': invoice,
           'preimage': preimage,
           'payment_hash': paymentHash,
           'amount': amount,
           if (description != null) 'description': description,
           if (descriptionHash != null) 'description_hash': descriptionHash,
           if (feesPaid != null) 'fees_paid': feesPaid,
           if (createdAtTimestamp != null) 'created_at': createdAtTimestamp,
           if (expiresAtTimestamp != null) 'expires_at': expiresAtTimestamp,
           if (settledAtTimestamp != null) 'settled_at': settledAtTimestamp,
           if (metadata != null) 'metadata': metadata,
         },
         createdAt: createdAt,
       );

  /// Create a payment sent notification
  PartialNwcNotification.paymentSent({
    required String clientPubkey,
    required String preimage,
    required String paymentHash,
    required int amount,
    String? invoice,
    String? description,
    String? descriptionHash,
    int? feesPaid,
    int? createdAtTimestamp,
    int? expiresAtTimestamp,
    int? settledAtTimestamp,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) : this(
         clientPubkey: clientPubkey,
         notificationType: NwcInfo.paymentSent,
         notification: {
           'type': 'outgoing',
           if (invoice != null) 'invoice': invoice,
           'preimage': preimage,
           'payment_hash': paymentHash,
           'amount': amount,
           if (description != null) 'description': description,
           if (descriptionHash != null) 'description_hash': descriptionHash,
           if (feesPaid != null) 'fees_paid': feesPaid,
           if (createdAtTimestamp != null) 'created_at': createdAtTimestamp,
           if (expiresAtTimestamp != null) 'expires_at': expiresAtTimestamp,
           if (settledAtTimestamp != null) 'settled_at': settledAtTimestamp,
           if (metadata != null) 'metadata': metadata,
         },
         createdAt: createdAt,
       );
}

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
/// Create and sign new NWC request events.
///
/// Example usage:
/// ```dart
/// final nwcRequest = await PartialNwcRequest(walletPubkey: walletKey, method: 'get_balance').signWith(signer);
/// ```
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

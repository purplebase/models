part of models;

/// Base class for NWC commands that can be sent to wallet services
abstract class NwcCommand<T> {
  /// The method name as defined in NIP-47
  String get method;

  /// The parameters for this command
  Map<String, dynamic> get params;

  /// Parse the response data into the expected result type
  T parseResponse(Map<String, dynamic> responseData);

  /// Create a partial request event for this command
  PartialNwcRequest toRequest({
    required String walletPubkey,
    DateTime? expiration,
    DateTime? createdAt,
  }) {
    final request = PartialNwcRequest(
      walletPubkey: walletPubkey,
      method: method,
      params: params,
      expiration: expiration,
      createdAt: createdAt,
    );

    return request;
  }

  /// Execute command with full error handling (recommended)
  /// Creates a signer from the connection's secret as per NIP-47 specification
  Future<T> executeRequest({
    required NwcConnection connection,
    required Ref ref,
    required StorageNotifier storage,
    DateTime? expiration,
    DateTime? createdAt,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Create a signer from the connection's secret (NIP-47 requirement)
    final connectionSigner = Bip340PrivateKeySigner(connection.secret, ref);
    await connectionSigner.signIn(registerSigner: false);

    // Create the request
    final request = toRequest(
      walletPubkey: connection.walletPubkey,
      expiration: expiration,
      createdAt: createdAt,
    );

    // Sign the request with the connection signer
    final signedRequest = await request.signWith(connectionSigner);

    // Start listening for response
    final completer = Completer<NwcResponse>();

    final sub = ref.listen(
      query<NwcResponse>(
        authors: {connection.walletPubkey},
        tags: {
          '#p': {connectionSigner.pubkey}, // Response directed to us
          '#e': {signedRequest.id}, // Response to our specific request
        },
        source: RemoteSource(relayUrls: {connection.relay}),
      ),
      (_, state) {
        if (state case StorageData(:final models)
            when models.isNotEmpty &&
                models.first.requestEventId == signedRequest.id &&
                !completer.isCompleted) {
          completer.complete(models.first);
        }
      },
    );

    // Publish to the connection's relay
    final publishResponse = await storage.publish({
      signedRequest,
    }, source: RemoteSource(relayUrls: {connection.relay}));

    // Check if publish was successful
    final publishSuccessful = publishResponse.results.values.any(
      (states) => states.any((state) => state.accepted),
    );

    if (!publishSuccessful) {
      throw Exception('Failed to publish NWC request to relay');
    }

    final response = await completer.future.timeout(timeout);
    sub.close();

    // Decrypt and process the response
    final decryptedContent = await response.decryptContent(connectionSigner);

    // Check for errors first
    final errorData = decryptedContent['error'] as Map<String, dynamic>?;
    if (errorData != null) {
      final error = NwcError.fromMap(errorData);
      throw NwcException(error);
    }

    // Extract and parse the result
    final resultData = decryptedContent['result'] as Map<String, dynamic>?;
    if (resultData == null) {
      throw Exception('NWC response missing result data');
    }

    return parseResponse(resultData);
  }
}

/// Exception thrown when NWC wallet service returns an error
class NwcException implements Exception {
  final NwcError error;

  const NwcException(this.error);

  @override
  String toString() => 'NwcException: ${error.code} - ${error.message}';
}

/// Result type for pay_invoice command
class PayInvoiceResult {
  final String preimage;
  final int? feesPaid;

  const PayInvoiceResult({required this.preimage, this.feesPaid});

  factory PayInvoiceResult.fromMap(Map<String, dynamic> map) {
    return PayInvoiceResult(
      preimage: map['preimage'] as String,
      feesPaid: map['fees_paid'] as int?,
    );
  }
}

/// Command to pay a Lightning invoice
class PayInvoiceCommand extends NwcCommand<PayInvoiceResult> {
  final String invoice;
  final int? amount;

  PayInvoiceCommand({required this.invoice, this.amount});

  /// Create a PayInvoiceCommand for a zap by handling all the complexity internally
  /// Handles zap request creation, profile lookup, and Lightning invoice generation
  static Future<PayInvoiceCommand> fromPubkey({
    required String recipientPubkey,
    required int amountSats,
    required Ref ref,
    String? comment,
    List<String> zapRelays = const [],
    Model? linkedModel,
  }) async {
    final storage = ref.read(storageNotifierProvider.notifier);

    // Step 1: Get the active signer
    final activeSigner = ref.read(Signer.activeSignerProvider);
    if (activeSigner == null) {
      throw Exception('No active signer found. Please sign in first.');
    }

    // Step 2: Create zap request
    final zapRequest = PartialZapRequest();
    zapRequest.amount = amountSats * 1000; // Convert to millisats
    zapRequest.comment = comment ?? '';
    zapRequest.relays = zapRelays;

    // Link to recipient
    zapRequest.linkProfileByPubkey(recipientPubkey);

    // Link to model if provided
    if (linkedModel != null) {
      zapRequest.linkModel(linkedModel);
    }

    final signedZapRequest = await zapRequest.signWith(activeSigner);

    // Step 3: Get recipient profile
    final recipientProfileState = await storage.query(
      RequestFilter<Profile>(authors: {recipientPubkey}).toRequest(),
      source: LocalAndRemoteSource(),
    );

    if (recipientProfileState.isEmpty) {
      throw Exception('Could not find recipient profile for Lightning invoice');
    }

    final recipientProfile = recipientProfileState.first;

    // Step 4: Get Lightning invoice
    final lightningInvoice = await recipientProfile.getLightningInvoice(
      amountSats: amountSats,
      comment: jsonEncode(signedZapRequest.toMap()),
    );

    if (lightningInvoice == null) {
      throw Exception(
        'Recipient does not support Lightning payments (no LNURL)',
      );
    }

    return PayInvoiceCommand(invoice: lightningInvoice);
  }

  @override
  String get method => NwcInfo.payInvoice;

  @override
  Map<String, dynamic> get params => {
    'invoice': invoice,
    if (amount != null) 'amount': amount,
  };

  @override
  PayInvoiceResult parseResponse(Map<String, dynamic> responseData) {
    return PayInvoiceResult.fromMap(responseData);
  }
}

/// Result type for get_balance command
class GetBalanceResult {
  final int balance;

  const GetBalanceResult({required this.balance});

  factory GetBalanceResult.fromMap(Map<String, dynamic> map) {
    return GetBalanceResult(balance: map['balance'] as int);
  }
}

/// Command to get wallet balance
class GetBalanceCommand extends NwcCommand<GetBalanceResult> {
  @override
  String get method => NwcInfo.getBalance;

  @override
  Map<String, dynamic> get params => {};

  @override
  GetBalanceResult parseResponse(Map<String, dynamic> responseData) {
    return GetBalanceResult.fromMap(responseData);
  }
}

/// Result type for make_invoice command
class MakeInvoiceResult {
  final String type;
  final String? invoice;
  final String? description;
  final String? descriptionHash;
  final String? preimage;
  final String paymentHash;
  final int amount;
  final int? feesPaid;
  final int? createdAt;
  final int? expiresAt;
  final Map<String, dynamic>? metadata;

  const MakeInvoiceResult({
    required this.type,
    this.invoice,
    this.description,
    this.descriptionHash,
    this.preimage,
    required this.paymentHash,
    required this.amount,
    this.feesPaid,
    this.createdAt,
    this.expiresAt,
    this.metadata,
  });

  factory MakeInvoiceResult.fromMap(Map<String, dynamic> map) {
    return MakeInvoiceResult(
      type: map['type'] as String,
      invoice: map['invoice'] as String?,
      description: map['description'] as String?,
      descriptionHash: map['description_hash'] as String?,
      preimage: map['preimage'] as String?,
      paymentHash: map['payment_hash'] as String,
      amount: map['amount'] as int,
      feesPaid: map['fees_paid'] as int?,
      createdAt: map['created_at'] as int?,
      expiresAt: map['expires_at'] as int?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Command to create a Lightning invoice
class MakeInvoiceCommand extends NwcCommand<MakeInvoiceResult> {
  final int amount;
  final String? description;
  final String? descriptionHash;
  final int? expiry;

  MakeInvoiceCommand({
    required this.amount,
    this.description,
    this.descriptionHash,
    this.expiry,
  });

  @override
  String get method => NwcInfo.makeInvoice;

  @override
  Map<String, dynamic> get params => {
    'amount': amount,
    if (description != null) 'description': description,
    if (descriptionHash != null) 'description_hash': descriptionHash,
    if (expiry != null) 'expiry': expiry,
  };

  @override
  MakeInvoiceResult parseResponse(Map<String, dynamic> responseData) {
    return MakeInvoiceResult.fromMap(responseData);
  }
}

/// Result type for get_info command
class GetInfoResult {
  final String? alias;
  final String? color;
  final String? pubkey;
  final String? network;
  final int? blockHeight;
  final String? blockHash;
  final List<String> methods;
  final List<String>? notifications;

  const GetInfoResult({
    this.alias,
    this.color,
    this.pubkey,
    this.network,
    this.blockHeight,
    this.blockHash,
    required this.methods,
    this.notifications,
  });

  factory GetInfoResult.fromMap(Map<String, dynamic> map) {
    return GetInfoResult(
      alias: map['alias'] as String?,
      color: map['color'] as String?,
      pubkey: map['pubkey'] as String?,
      network: map['network'] as String?,
      blockHeight: map['block_height'] as int?,
      blockHash: map['block_hash'] as String?,
      methods: (map['methods'] as List<dynamic>).cast<String>(),
      notifications: (map['notifications'] as List<dynamic>?)?.cast<String>(),
    );
  }
}

/// Command to get wallet info
class GetInfoCommand extends NwcCommand<GetInfoResult> {
  @override
  String get method => NwcInfo.getInfo;

  @override
  Map<String, dynamic> get params => {};

  @override
  GetInfoResult parseResponse(Map<String, dynamic> responseData) {
    return GetInfoResult.fromMap(responseData);
  }
}

/// Result type for lookup_invoice command
class LookupInvoiceResult {
  final String type;
  final String? invoice;
  final String? description;
  final String? descriptionHash;
  final String? preimage;
  final String paymentHash;
  final int amount;
  final int? feesPaid;
  final int? createdAt;
  final int? expiresAt;
  final int? settledAt;
  final Map<String, dynamic>? metadata;

  const LookupInvoiceResult({
    required this.type,
    this.invoice,
    this.description,
    this.descriptionHash,
    this.preimage,
    required this.paymentHash,
    required this.amount,
    this.feesPaid,
    this.createdAt,
    this.expiresAt,
    this.settledAt,
    this.metadata,
  });

  factory LookupInvoiceResult.fromMap(Map<String, dynamic> map) {
    return LookupInvoiceResult(
      type: map['type'] as String,
      invoice: map['invoice'] as String?,
      description: map['description'] as String?,
      descriptionHash: map['description_hash'] as String?,
      preimage: map['preimage'] as String?,
      paymentHash: map['payment_hash'] as String,
      amount: map['amount'] as int,
      feesPaid: map['fees_paid'] as int?,
      createdAt: map['created_at'] as int?,
      expiresAt: map['expires_at'] as int?,
      settledAt: map['settled_at'] as int?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Check if this invoice/payment is settled
  bool get isSettled => settledAt != null;
}

/// Command to lookup an invoice by payment hash or invoice string
class LookupInvoiceCommand extends NwcCommand<LookupInvoiceResult> {
  final String? paymentHash;
  final String? invoice;

  LookupInvoiceCommand({this.paymentHash, this.invoice})
    : assert(
        paymentHash != null || invoice != null,
        'Either paymentHash or invoice must be provided',
      );

  @override
  String get method => NwcInfo.lookupInvoice;

  @override
  Map<String, dynamic> get params => {
    if (paymentHash != null) 'payment_hash': paymentHash,
    if (invoice != null) 'invoice': invoice,
  };

  @override
  LookupInvoiceResult parseResponse(Map<String, dynamic> responseData) {
    return LookupInvoiceResult.fromMap(responseData);
  }
}

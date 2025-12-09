part of models;

/// Base class for NWC commands that can be sent to wallet services
abstract class NwcCommand<T> {
  /// The method name as defined in NIP-47
  String get method;

  /// The parameters for this command
  Map<String, dynamic> get params;

  /// Parse the response data into the expected result type
  T parseResponse(Map<String, dynamic> responseData);

  /// Execute command with the provided NWC connection URI string
  /// Automatically handles connection parsing, relay routing, signing, and error handling
  Future<T> execute({
    required String connectionUri,
    required Ref ref,
    DateTime? expiration,
    DateTime? createdAt,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final connection = NwcConnection.fromUri(connectionUri);
    return await _executeRequest(
      connection: connection,
      ref: ref,
      expiration: expiration,
      createdAt: createdAt,
      timeout: timeout,
    );
  }

  /// Execute command with full error handling (recommended)
  /// Creates a signer from the connection's secret as per NIP-47 specification
  Future<T> _executeRequest({
    required NwcConnection connection,
    required Ref ref,
    DateTime? expiration,
    DateTime? createdAt,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Create a signer from the connection's secret (NIP-47 requirement)
    final connectionSigner = Bip340PrivateKeySigner(connection.secret, ref);
    await connectionSigner.signIn(registerSigner: false);

    // Create the request
    final request = PartialNwcRequest(
      walletPubkey: connection.walletPubkey,
      method: method,
      params: params,
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
        source: RemoteSource(relays: connection.relay),
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
    final publishResponse = await ref.storage.publish({
      signedRequest,
    }, source: RemoteSource(relays: connection.relay));

    // Check if publish was successful
    final publishSuccessful = publishResponse.results.values.any(
      (states) => states.any((state) => state.accepted),
    );

    if (!publishSuccessful) {
      throw Exception('Failed to publish NWC request to relay');
    }

    final response = await completer.future.timeout(timeout);
    sub.close();

    // Get the response content (already plaintext)
    final decryptedContent = response.getContentMap();

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

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
    Duration timeout = const Duration(seconds: 30),
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
    Duration timeout = const Duration(seconds: 30),
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

    // Sign the request with the connection signer (uses NIP-04 encryption)
    final signedRequest = await request.signWith(connectionSigner);

    // Wrap relay in a Set as expected by the query system
    final relaySet = {connection.relay};

    // Build the request for querying NWC responses
    final responseRequest = RequestFilter<NwcResponse>(
      authors: {connection.walletPubkey},
      tags: {
        '#p': {connectionSigner.pubkey}, // Response directed to us
        '#e': {signedRequest.id}, // Response to our specific request
      },
    ).toRequest();

    final storageNotifier = ref.read(storageNotifierProvider.notifier);
    final completer = Completer<NwcResponse>();
    void Function()? cancelListener;

    try {
      // Set up listener FIRST to catch any responses
      cancelListener = storageNotifier.addListener((state) {
        if (completer.isCompleted) return;

        // Check if this update might contain our response
        if (state is InternalStorageData && state.updatedIds.isNotEmpty) {
          // Query for matching response
          final responses = storageNotifier.querySync<NwcResponse>(
            responseRequest,
          );

          for (final r in responses) {
            if (r.requestEventId == signedRequest.id &&
                !completer.isCompleted) {
              completer.complete(r);
              return;
            }
          }
        }
      });

      // Establish the streaming subscription
      // stream: true (default) returns immediately and keeps the subscription
      // open to receive the wallet's response via callbacks
      await ref.storage.query(
        responseRequest,
        source: RemoteSource(relays: relaySet),
      );

      // Publish to the connection's relay
      final publishResponse = await ref.storage.publish({
        signedRequest,
      }, source: RemoteSource(relays: relaySet));

      // Check if publish was successful
      final publishSuccessful = publishResponse.results.values.any(
        (states) => states.any((state) => state.accepted),
      );

      if (!publishSuccessful) {
        throw Exception('Failed to publish NWC request to relay');
      }

      // Wait for the response with timeout
      final response = await completer.future.timeout(timeout);

      // Decrypt the response content - NWC uses NIP-04 encryption
      final decryptedContentStr = await connectionSigner.nip04Decrypt(
        response.content,
        connection.walletPubkey,
      );

      final decryptedContent =
          jsonDecode(decryptedContentStr) as Map<String, dynamic>;

      if (!decryptedContent.containsKey('result_type')) {
        throw Exception('NWC response missing required "result_type" field');
      }

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
    } finally {
      // Clean up the listener
      cancelListener?.call();

      // Cancel the subscription
      await ref.storage.cancel(responseRequest);
    }
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
  final String? preimage;
  final int? feesPaid;

  const PayInvoiceResult({this.preimage, this.feesPaid});

  factory PayInvoiceResult.fromMap(Map<String, dynamic> map) {
    return PayInvoiceResult(
      preimage: map['preimage'] as String?,
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

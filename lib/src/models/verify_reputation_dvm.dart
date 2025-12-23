part of models;

/// A DVM error event (kind 7000) indicating an error in DVM processing.
///
/// DVM errors provide status information when DVM requests fail.
class DVMError extends RegularModel<DVMError> {
  DVMError.fromMap(super.map, super.ref) : super.fromMap();

  /// Error status message
  String? get status => event.getFirstTagValue('status');
}

/// A reputation verification request event (kind 5312) for DVM services.
///
/// This event requests reputation verification from Data Vending Machines (DVMs).
/// DVMs process the request and return verification responses.
class VerifyReputationRequest extends RegularModel<VerifyReputationRequest>
    with DVMRequest<VerifyReputationRequest> {
  VerifyReputationRequest.fromMap(super.map, super.ref) : super.fromMap();

  @override
  int get responseKind => 6312;
}

/// Create and sign new reputation verification requests.
class PartialVerifyReputationRequest
    extends RegularPartialModel<VerifyReputationRequest>
    with DVMPartialRequest<VerifyReputationRequest> {
  PartialVerifyReputationRequest.fromMap(super.map) : super.fromMap();

  /// Creates a new reputation verification request
  ///
  /// [source] - Source identifier for reputation lookup
  /// [target] - Target identifier to verify reputation for
  PartialVerifyReputationRequest({
    required String source,
    required String target,
    String? sort,
    int? limit,
  }) {
    addParam('source', source);
    addParam('target', target);
    addOptionalParam('sort', sort);
    addOptionalIntParam('limit', limit);
  }
}

/// A reputation verification response event (kind 6312) from DVM services.
///
/// This event contains the response from DVMs after processing reputation
/// verification requests.
class VerifyReputationResponse extends RegularModel<VerifyReputationResponse> {
  VerifyReputationResponse.fromMap(super.map, super.ref) : super.fromMap();

  /// Set of public keys returned in the verification response
  Set<String> get pubkeys => (jsonDecode(event.content) as Iterable)
      .map((e) => e['pubkey'].toString())
      .toSet();
}

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
class VerifyReputationRequest extends RegularModel<VerifyReputationRequest> {
  VerifyReputationRequest.fromMap(super.map, super.ref) : super.fromMap();

  /// Execute verification request and wait for response
  ///
  /// [relayGroup] - The relay group to publish the request to
  /// Returns the first DVM response (success or error)
  Future<Model<dynamic>?> run(String relayGroup) async {
    final source = RemoteSource(group: relayGroup);
    // Just publish, do not save
    await storage.publish({this}, source: source);
    final responses = await storage.query(
      RequestFilter(
        kinds: {6312, 7000},
        tags: {
          'e': {event.id},
        },
      ).toRequest(),
      source: source,
    );
    return responses.firstOrNull;
  }
}

/// Create and sign new reputation verification requests.
class PartialVerifyReputationRequest
    extends RegularPartialModel<VerifyReputationRequest> {
  PartialVerifyReputationRequest.fromMap(super.map) : super.fromMap();

  /// Creates a new reputation verification request
  ///
  /// [source] - Source identifier for reputation lookup
  /// [target] - Target identifier to verify reputation for
  PartialVerifyReputationRequest({
    required String source,
    required String target,
  }) {
    event.addTag('param', ['source', source]);
    event.addTag('param', ['target', target]);
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

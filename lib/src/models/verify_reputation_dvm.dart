part of models;

class DVMError extends RegularModel<DVMError> {
  DVMError.fromMap(super.map, super.ref) : super.fromMap();
  String? get status => event.getFirstTagValue('status');
}

class VerifyReputationRequest extends RegularModel<VerifyReputationRequest> {
  VerifyReputationRequest.fromMap(super.map, super.ref) : super.fromMap();
  Future<Model<dynamic>?> run(String relayGroup) async {
    final source = RemoteSource(group: relayGroup);
    // Just publish, do not save
    await storage.publish({this}, source: source);
    final responses = await storage.query(
        RequestFilter(
          kinds: {6312, 7000},
          tags: {
            'e': {event.id}
          },
        ).toRequest(),
        source: source);
    return responses.firstOrNull;
  }
}

class PartialVerifyReputationRequest
    extends RegularPartialModel<VerifyReputationRequest> {
  PartialVerifyReputationRequest({
    required String source,
    required String target,
  }) {
    event.addTag('param', ['source', source]);
    event.addTag('param', ['target', target]);
  }
}

class VerifyReputationResponse extends RegularModel<VerifyReputationResponse> {
  VerifyReputationResponse.fromMap(super.map, super.ref) : super.fromMap();
  Set<String> get pubkeys => (jsonDecode(event.content) as Iterable)
      .map((e) => e['pubkey'].toString())
      .toSet();
}

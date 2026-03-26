/// Response from publishing events to relays.
final class PublishResponse {
  final Map<String, Set<RelayEventState>> results = {};
  Set<String> unreachableRelayUrls = {};

  void addEvent(
    String eventId, {
    required String relayUrl,
    bool accepted = true,
    String? message,
  }) {
    results[eventId] ??= {};
    results[eventId]!.add(
      RelayEventState(relayUrl, accepted: accepted, message: message),
    );
  }
}

/// State of a single event on a specific relay.
final class RelayEventState {
  final String relayUrl;
  final bool accepted;
  final String? message;
  const RelayEventState(this.relayUrl, {this.accepted = true, this.message});
}

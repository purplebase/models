import 'package:models/models.dart';

class TargetedPublication
    extends ParameterizableReplaceableEvent<TargetedPublication> {
  late final BelongsTo<Event> event;
  late final HasMany<Community> communities;

  TargetedPublication.fromMap(super.map, super.ref) : super.fromMap() {
    event =
        BelongsTo(ref, RequestFilter(ids: {internal.getFirstTagValue('d')!}));
    communities = HasMany(ref,
        RequestFilter.fromReplaceableEvents(internal.getTagSetValues('p')));
  }
  int get targetedKind => int.parse(internal.getFirstTagValue('k')!);
  Set<String> get relayUrls => internal.getTagSetValues('r');
}

class PartialTargetedPublication
    extends ParameterizableReplaceablePartialEvent<TargetedPublication> {
  PartialTargetedPublication(Event event,
      {required Set<Community> communities, Set<String>? relayUrls}) {
    internal.addTagValue('d', event.id);
    internal.addTagValue('k', event.internal.kind.toString());
    for (final community in communities) {
      internal.addTagValue('p', community.id);
    }
    if (relayUrls != null) {
      for (final relayUrl in relayUrls) {
        internal.addTagValue('r', relayUrl);
      }
    }
  }

  void addCommunityPubkey(String value) => internal.addTagValue('p', value);
  set eventId(String value) => internal.addTagValue('e', value);
  set eventKind(int value) => internal.addTagValue('k', value.toString());
}

part of models;

/// Zap is technically a kind 9735 Zap Receipt
class Zap extends RegularEvent<Zap> {
  @override
  BelongsTo<Profile> get author => BelongsTo(ref,
      RequestFilter(kinds: {0}, authors: {internal.getFirstTagValue('P')!}));
  late final BelongsTo<Event> zappedEvent;
  late final BelongsTo<Profile> recipient;

  Zap.fromMap(super.map, super.ref) : super.fromMap() {
    recipient = BelongsTo(ref,
        RequestFilter(kinds: {0}, authors: {internal.getFirstTagValue('p')!}));
    zappedEvent =
        BelongsTo(ref, RequestFilter(ids: {internal.getFirstTagValue('e')!}));
  }

  @override
  Future<Map<String, dynamic>> processMetadata() async {
    final amount = getSatsFromBolt11(internal.getFirstTagValue('bolt11')!);
    return {'amount': amount};
  }

  @override
  Map<String, dynamic> transformEventMap(Map<String, dynamic> event) {
    // Remove bolt11, preimage, description
    (event['tags'] as List).removeWhere(
        (t) => ['bolt11', 'preimage', 'description'].contains(t[0]));
    return event;
  }

  /// Amount in sats
  int get amount {
    return internal.metadata['amount'];
  }
}

class ZapRequest extends RegularEvent<ZapRequest> {
  ZapRequest.fromMap(super.map, super.ref) : super.fromMap();
}

class PartialZapRequest extends RegularPartialEvent<ZapRequest> {
  set comment(String? value) => value != null ? internal.content = value : null;
  set amount(int value) => internal.setTagValue('amount', value.toString());
  set relays(Iterable<String> value) =>
      internal.addTag('relays', value.toList());
  set lnurl(String value) => internal.setTagValue('lnurl', value);
}

final kBolt11Regexp = RegExp(r'lnbc(\d+)([munp])');

int getSatsFromBolt11(String bolt11) {
  try {
    final m = kBolt11Regexp.allMatches(bolt11);
    final [baseAmountInBitcoin, multiplier] = m.first.groups([1, 2]);
    final a = int.tryParse(baseAmountInBitcoin!)!;
    final amountInBitcoin = switch (multiplier!) {
      'm' => a * 0.001,
      'u' => a * 0.000001,
      'n' => a * 0.000000001,
      'p' => a * 0.000000000001,
      _ => a,
    };
    // Return converted to sats
    return (amountInBitcoin * 100000000).floor();
  } catch (_) {
    // Do not bother throwing an exception, 0 sat should still convey that it was an error
    return 0;
  }
}

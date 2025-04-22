part of models;

/// Zap is technically a kind 9735 Zap Receipt
class Zap extends RegularModel<Zap> {
  @override
  BelongsTo<Profile> get author =>
      BelongsTo(ref, RequestFilter(authors: {event.getFirstTagValue('P')!}));
  late final BelongsTo<Model> zappedModel;
  late final BelongsTo<Profile> recipient;

  Zap.fromMap(super.map, super.ref) : super.fromMap() {
    recipient =
        BelongsTo(ref, RequestFilter(authors: {event.getFirstTagValue('p')!}));
    zappedModel =
        BelongsTo(ref, RequestFilter(ids: {event.getFirstTagValue('e')!}));
  }

  @override
  Map<String, dynamic> processMetadata() {
    final amount = getSatsFromBolt11(event.getFirstTagValue('bolt11')!);
    return {'amount': amount};
  }

  @override
  Map<String, dynamic> transformMap(Map<String, dynamic> map) {
    // Remove bolt11, preimage, description
    (map['tags'] as List).removeWhere(
        (t) => ['bolt11', 'preimage', 'description'].contains(t[0]));
    return super.transformMap(map);
  }

  /// Amount in sats
  int get amount {
    return event.metadata['amount'];
  }
}

class ZapRequest extends RegularModel<ZapRequest> {
  ZapRequest.fromMap(super.map, super.ref) : super.fromMap();
}

class PartialZapRequest extends RegularPartialModel<ZapRequest> {
  set comment(String? value) => value != null ? event.content = value : null;
  set amount(int value) => event.setTagValue('amount', value.toString());
  set relays(Iterable<String> value) => event.addTag('relays', value.toList());
  set lnurl(String value) => event.setTagValue('lnurl', value);
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

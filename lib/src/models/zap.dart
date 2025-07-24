part of models;

/// Zap is technically a kind 9735 Zap Receipt

class Zap extends RegularModel<Zap> {
  @override
  BelongsTo<Profile> get author => BelongsTo(
    ref,
    RequestFilter<Profile>(
      authors: {event.getFirstTagValue('P') ?? event.metadata['author']},
    ).toRequest(),
  );

  late final BelongsTo<Model> zappedModel;
  late final BelongsTo<Profile> wallet;
  late final BelongsTo<Profile> recipient;
  late final BelongsTo<ZapRequest> zapRequest;

  Zap.fromMap(super.map, super.ref) : super.fromMap() {
    wallet = BelongsTo(
      ref,
      RequestFilter<Profile>(authors: {event.pubkey}).toRequest(),
    );
    recipient = BelongsTo(
      ref,
      RequestFilter<Profile>(
        authors: {event.getFirstTagValue('p')!},
      ).toRequest(),
    );
    zappedModel = BelongsTo(
      ref,
      Request.fromIds({
        ?event.getFirstTagValue('e'),
        ?event.getFirstTagValue('a'),
      }),
    );
    zapRequest = BelongsTo(
      ref,
      RequestFilter<ZapRequest>(
        ids: {event.metadata['zapRequestId']!},
      ).toRequest(),
    );
  }

  @override
  Map<String, dynamic> processMetadata() {
    final amount = _getSatsFromBolt11(event.getFirstTagValue('bolt11')!);
    final description = jsonDecode(event.getFirstTagValue('description')!);
    return {
      'amount': amount,
      'zapRequestId': description['id'],
      'author': description['pubkey'],
    };
  }

  @override
  Map<String, dynamic> transformMap(Map<String, dynamic> map) {
    // Remove bolt11, preimage, description
    (map['tags'] as List).removeWhere(
      (t) => ['bolt11', 'preimage', 'description'].contains(t[0]),
    );
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

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for ZapRequest
mixin PartialZapRequestMixin on RegularPartialModel<ZapRequest> {
  String? get comment => event.content.isEmpty ? null : event.content;
  set comment(String? value) => event.content = value ?? '';

  int? get amount => int.tryParse(event.getFirstTagValue('amount') ?? '');
  set amount(int? value) {
    if (value != null) {
      event.setTagValue('amount', value.toString());
    } else {
      event.removeTag('amount');
    }
  }

  List<String> get relays {
    final relaysTag = event.tags
        .where((tag) => tag.isNotEmpty && tag[0] == 'relays')
        .firstOrNull;
    if (relaysTag == null || relaysTag.length <= 1) return [];
    return relaysTag.skip(1).toList();
  }

  set relays(Iterable<String> value) {
    if (value.isNotEmpty) {
      event.setTag('relays', value.toList());
    } else {
      event.removeTag('relays');
    }
  }

  String? get lnurl => event.getFirstTagValue('lnurl');
  set lnurl(String? value) {
    if (value != null && value.isNotEmpty) {
      event.setTagValue('lnurl', value);
    } else {
      event.removeTag('lnurl');
    }
  }
}

class PartialZapRequest extends RegularPartialModel<ZapRequest>
    with PartialZapRequestMixin {
  PartialZapRequest.fromMap(super.map) : super.fromMap();
  PartialZapRequest();
}

/// Partial model for creating Zap receipts (kind 9735)
class PartialZap extends RegularPartialModel<Zap> {
  PartialZap.fromMap(super.map) : super.fromMap();

  PartialZap({
    required String recipientPubkey,
    required String zapRequestId,
    required int amountSats,
    required String preimage,
    required Model? zappedModel,
    String? description,
  }) {
    // Create fake BOLT11 invoice for the amount
    final bolt11 = 'lnbc${amountSats * 1000}n1pjqwdqcpp5${'a' * 52}fake';

    // Add required tags for zap receipt
    event.addTag('bolt11', [bolt11]);
    event.addTag('description', [
      description ??
          jsonEncode({
            'id': zapRequestId,
            'kind': 9734,
            'content': '',
            'tags': [],
            'pubkey': event.pubkey,
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          }),
    ]);
    event.addTag('preimage', [preimage]);
    event.addTag('p', [recipientPubkey]);

    // Link to zapped model if provided
    if (zappedModel != null) {
      linkModel(zappedModel);
    }

    event.content = '';
  }
}

final kBolt11Regexp = RegExp(r'lnbc(\d+)([munp])');

int _getSatsFromBolt11(String bolt11) {
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

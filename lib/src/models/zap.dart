part of models;

/// A zap event (kind 9735) representing a Lightning Network payment.
///
/// Zaps are Bitcoin Lightning payments sent to content creators as tips or
/// donations. They include the payment amount and can include a message.
class Zap extends RegularModel<Zap> {
  /// Overrides the default author to point to the wallet that sent the zap
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

  /// Payment amount in satoshis
  int get amount {
    return event.metadata['amount'];
  }
}

/// A zap request event (kind 9734) used to request Lightning payments
class ZapRequest extends RegularModel<ZapRequest> {
  ZapRequest.fromMap(super.map, super.ref) : super.fromMap() {
    // use constructor body?
  }

  /// Pay this zap request using the signer's NWC connection
  /// This should be called on a signed ZapRequest that contains all necessary information
  ///
  /// [expiration] - Optional expiration time for the payment
  /// [timeout] - How long to wait for payment completion
  Future<PayInvoiceResult> pay({
    DateTime? expiration,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Get the signer for this zap request
    final signer = ref.read(Signer.signerProvider(event.pubkey));
    if (signer == null) {
      throw Exception('No signer found for pubkey ${event.pubkey}');
    }

    // Get the NWC connection string from the signer
    final nwcConnectionString = await signer.getNWCString();
    if (nwcConnectionString == null) {
      throw Exception(
        'No NWC connection configured for signer. Use signer.setNWCString() first.',
      );
    }

    // Parse the connection string
    final connection = NwcConnection.fromUri(nwcConnectionString);

    // Check if connection has expired
    if (connection.isExpired) {
      throw Exception('NWC connection has expired');
    }

    final storage = ref.read(storageNotifierProvider.notifier);

    // Get the recipient pubkey from the zap request
    final recipientPubkey = event.getFirstTagValue('p');
    if (recipientPubkey == null) {
      throw Exception('Zap request missing recipient pubkey (p tag)');
    }

    // Get recipient profile for Lightning invoice
    final recipientProfileState = await storage.query(
      RequestFilter<Profile>(authors: {recipientPubkey}).toRequest(),
      source: LocalAndRemoteSource(stream: false),
    );

    if (recipientProfileState.isEmpty) {
      throw Exception('Could not find recipient profile for Lightning invoice');
    }

    final recipientProfile = recipientProfileState.first;

    // Get the amount from the zap request (in millisats, convert to sats)
    final amountTag = event.getFirstTagValue('amount');
    if (amountTag == null) {
      throw Exception('Zap request missing amount tag');
    }
    final amountMillisats = int.tryParse(amountTag);
    if (amountMillisats == null) {
      throw Exception('Invalid amount in zap request: $amountTag');
    }
    final amountSats = amountMillisats ~/ 1000;

    // Get Lightning invoice from recipient profile
    final lightningInvoice = await recipientProfile.getLightningInvoice(
      amountSats: amountSats,
      comment: event.content.isEmpty ? null : event.content,
      zapRequest: toMap(),
    );

    if (lightningInvoice == null) {
      throw Exception(
        'Recipient does not support Lightning payments (no LNURL)',
      );
    }

    // Create and execute the pay invoice command
    final command = PayInvoiceCommand(invoice: lightningInvoice);

    return await command.execute(
      connectionUri: nwcConnectionString,
      ref: ref,
      expiration: expiration,
      timeout: timeout,
    );
  }
}

/// Generated partial model mixin for ZapRequest
mixin PartialZapRequestMixin on RegularPartialModel<ZapRequest> {
  /// Optional comment or message to include with the zap
  String? get comment => event.content.isEmpty ? null : event.content;

  /// Sets the zap comment
  set comment(String? value) => event.content = value ?? '';

  /// Payment amount in millisatoshis
  int? get amount => int.tryParse(event.getFirstTagValue('amount') ?? '');

  /// Sets the payment amount in millisatoshis
  set amount(int? value) {
    if (value != null) {
      event.setTagValue('amount', value.toString());
    } else {
      event.removeTag('amount');
    }
  }

  /// List of relay URLs for the zap request
  List<String> get relays {
    final relaysTag = event.tags
        .where((tag) => tag.isNotEmpty && tag[0] == 'relays')
        .firstOrNull;
    if (relaysTag == null || relaysTag.length <= 1) return [];
    return relaysTag.skip(1).toList();
  }

  /// Sets the relay URLs
  set relays(Iterable<String> value) {
    if (value.isNotEmpty) {
      event.setTag('relays', value.toList());
    } else {
      event.removeTag('relays');
    }
  }

  /// LNURL-pay endpoint for the recipient
  String? get lnurl => event.getFirstTagValue('lnurl');

  /// Sets the LNURL-pay endpoint
  set lnurl(String? value) {
    if (value?.isNotEmpty == true) {
      event.setTagValue('lnurl', value!);
    } else {
      event.removeTag('lnurl');
    }
  }
}

class PartialZapRequest extends RegularPartialModel<ZapRequest>
    with PartialZapRequestMixin {
  PartialZapRequest.fromMap(super.map) : super.fromMap();

  /// Creates a new zap request
  PartialZapRequest();
}

/// Partial model for creating Zap receipts (kind 9735)
class PartialZap extends RegularPartialModel<Zap> {
  PartialZap.fromMap(super.map) : super.fromMap();

  /// Creates a new zap receipt
  ///
  /// [recipientPubkey] - Public key of the zap recipient
  /// [zapRequestId] - ID of the original zap request
  /// [amountSats] - Payment amount in satoshis
  /// [preimage] - Lightning payment preimage
  /// [zappedModel] - Optional model that was zapped
  /// [description] - Optional description (JSON-encoded zap request)
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

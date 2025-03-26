import 'dart:convert';

import 'package:models/src/core/event.dart';
import 'package:models/src/core/utils.dart';

class ZapReceipt = RegularEvent<ZapReceipt> with ZapReceiptMixin;

mixin ZapReceiptMixin on EventBase<ZapReceipt> {
  String get eventId => internal.getFirstTagValue('e')!;
  String get receiverPubkey => internal.getFirstTagValue('p')!;
  Map<String, dynamic> get description =>
      internal.getFirstTagValue('description') != null
          ? Map<String, dynamic>.from(
              jsonDecode(internal.getFirstTagValue('description')!))
          : {};
  String get senderPubkey =>
      internal.getFirstTagValue('P') ?? description['pubkey'];

  /// Amount in sats
  int get amount {
    return getSatsFromBolt11(internal.getFirstTagValue('bolt11')!);
  }
}

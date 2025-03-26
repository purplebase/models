import 'dart:convert';

import 'package:models/src/core/event.dart';
import 'package:models/src/core/utils.dart';

class ZapReceipt = RegularEvent<ZapReceipt> with ZapReceiptMixin;

mixin ZapReceiptMixin on EventBase<ZapReceipt> {
  String get eventId => event.getFirstTagValue('e')!;
  String get receiverPubkey => event.getFirstTagValue('p')!;
  Map<String, dynamic> get description =>
      event.getFirstTagValue('description') != null
          ? Map<String, dynamic>.from(
              jsonDecode(event.getFirstTagValue('description')!))
          : {};
  String get senderPubkey =>
      event.getFirstTagValue('P') ?? description['pubkey'];

  /// Amount in sats
  int get amount {
    return getSatsFromBolt11(event.getFirstTagValue('bolt11')!);
  }
}

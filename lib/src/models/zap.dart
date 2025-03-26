import 'dart:convert';

import 'package:models/src/core/event.dart';
import 'package:models/src/core/utils.dart';

/// Zap is technically a kind 9735 Zap Receipt
class Zap extends RegularEvent<Zap> {
  Zap.fromMap(super.map, super.ref) : super.fromMap();

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

class ZapRequest extends RegularEvent<ZapRequest> {
  ZapRequest.fromMap(super.map, super.ref) : super.fromMap();
}

class PartialZapRequest extends RegularPartialEvent<ZapRequest> {
  set comment(String? value) => value != null ? internal.content = value : null;
  set amount(int value) => internal.setTagValue('amount', value.toString());
  set relays(Iterable<String> value) =>
      internal.addTag('relays', TagValue(value.toList()));
  set lnurl(String value) => internal.setTagValue('lnurl', value);
}

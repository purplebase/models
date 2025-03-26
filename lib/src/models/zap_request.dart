import 'package:models/src/core/event.dart';

class ZapRequest extends RegularEvent<ZapRequest> {
  ZapRequest.fromJson(super.map, super.ref) : super.fromJson();
}

class PartialZapRequest extends RegularPartialEvent<ZapRequest> {
  set comment(String? value) => value != null ? event.content = value : null;
  set amount(int value) => event.setTagValue('amount', value.toString());
  set relays(Iterable<String> value) =>
      event.addTag('relays', TagValue(value.toList()));
  set lnurl(String value) => event.setTagValue('lnurl', value);
}

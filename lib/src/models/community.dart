import 'package:models/models.dart';

class Community extends ParameterizableReplaceableEvent<Community> {
  Community.fromMap(super.map, super.ref) : super.fromMap();
  String get name => internal.getFirstTagValue('name')!;
}

class PartialCommunity
    extends ParameterizableReplaceablePartialEvent<Community> {
  PartialCommunity(String name) {
    internal.addTagValue('name', name);
  }
}

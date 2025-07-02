part of models;

@GeneratePartialModel()
class CustomData extends ParameterizableReplaceableModel<CustomData> {
  CustomData.fromMap(super.map, super.ref) : super.fromMap();

  /// The custom data content (arbitrary JSON)
  String get content => event.content;

  /// The identifier for this custom data (from d tag)
  @override
  String get identifier => event.identifier;
}

class PartialCustomData
    extends ParameterizableReplaceablePartialEvent<CustomData>
    with PartialCustomDataMixin {
  PartialCustomData({
    required String identifier,
    required String content,
  }) {
    this.identifier = identifier;
    event.content = content;
  }
}

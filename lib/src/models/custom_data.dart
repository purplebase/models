part of models;

@GeneratePartialModel()
class CustomData extends ParameterizableReplaceableModel<CustomData> {
  CustomData.fromMap(super.map, super.ref) : super.fromMap();

  /// The custom data content (arbitrary JSON)
  String get content => event.content;
}

class PartialCustomData
    extends ParameterizableReplaceablePartialModel<CustomData>
    with PartialCustomDataMixin {
  PartialCustomData.fromMap(super.map) : super.fromMap();

  PartialCustomData({
    required String identifier,
    required String content,
  }) {
    this.identifier = identifier;
    event.content = content;
  }

  setProperty(String key, String value) => event.setTagValue(key, value);
}

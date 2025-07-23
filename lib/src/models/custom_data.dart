part of models;

class CustomData extends ParameterizableReplaceableModel<CustomData> {
  CustomData.fromMap(super.map, super.ref) : super.fromMap();

  /// The custom data content (arbitrary JSON)
  String get content => event.content;
}

// ignore_for_file: annotate_overrides

/// Generated partial model mixin for CustomData
mixin PartialCustomDataMixin
    on ParameterizableReplaceablePartialModel<CustomData> {
  String? get content => event.content.isEmpty ? null : event.content;
  set content(String? value) => event.content = value ?? '';
}

class PartialCustomData
    extends ParameterizableReplaceablePartialModel<CustomData>
    with PartialCustomDataMixin {
  PartialCustomData.fromMap(super.map) : super.fromMap();

  PartialCustomData({required String identifier, required String content}) {
    this.identifier = identifier;
    event.content = content;
  }

  setProperty(String key, String value) => event.setTagValue(key, value);
}

part of models;

/// A custom data event (kind 30078) for storing arbitrary application data.
///
/// Custom data events provide a way to store application-specific data
/// on Nostr relays. They are parameterizable replaceable events.
class CustomData extends ParameterizableReplaceableModel<CustomData> {
  CustomData.fromMap(super.map, super.ref) : super.fromMap();

  /// The custom data content (arbitrary JSON or text)
  String get content => event.content;
}

/// Generated partial model mixin for CustomData
mixin PartialCustomDataMixin
    on ParameterizableReplaceablePartialModel<CustomData> {
  /// The custom data content
  String? get content => event.content.isEmpty ? null : event.content;

  /// Sets the custom data content
  set content(String? value) => event.content = value ?? '';
}

/// Create and sign new custom data events.
class PartialCustomData
    extends ParameterizableReplaceablePartialModel<CustomData>
    with PartialCustomDataMixin {
  PartialCustomData.fromMap(super.map) : super.fromMap();

  /// Creates a new custom data event
  ///
  /// [identifier] - Unique identifier for this data
  /// [content] - The data content (JSON, text, etc.)
  PartialCustomData({required String identifier, required String content}) {
    this.identifier = identifier;
    event.content = content;
  }

  /// Gets a custom property as a tag
  ///
  /// [key] - The property key
  String? getProperty(String key) => event.getFirstTagValue(key);

  /// Sets a custom property as a tag
  ///
  /// [key] - The property key
  /// [value] - The property value
  setProperty(String key, String value) => event.setTagValue(key, value);
}

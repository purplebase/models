import '../core/model.dart';

/// Mixin for DVM request models that follows NIP-90 conventions.
///
/// DVM (Data Vending Machine) requests:
/// - Response kind = request kind + 1000
/// - Error kind = 7000
/// - Responses reference the request via `#e` tag
///
/// The `run()` method has been moved to the provider layer since it
/// requires Riverpod for subscription management and publishing.
mixin DVMRequest<E extends Model<E>> on RegularModel<E> {
  /// The response kind for this DVM request.
  ///
  /// Per NIP-90, this is typically the request kind + 1000.
  int get responseKind;
}

/// Mixin for partial DVM request models with param tag helpers.
///
/// Provides convenient methods for adding NIP-90 param tags to DVM requests.
///
/// Usage:
/// ```dart
/// class PartialMyDVMRequest extends RegularPartialModel<MyDVMRequest>
///     with DVMPartialRequest<MyDVMRequest> {
///   PartialMyDVMRequest({required String input}) {
///     addParam('input', input);
///   }
/// }
/// ```
mixin DVMPartialRequest<E extends Model<E>> on RegularPartialModel<E> {
  /// Add a single param tag with key and value.
  ///
  /// Creates a tag in the format: `["param", key, value]`
  void addParam(String key, String value) {
    event.addTag('param', [key, value]);
  }

  /// Add multiple param tags from a map.
  void addParams(Map<String, String> params) {
    for (final entry in params.entries) {
      addParam(entry.key, entry.value);
    }
  }

  /// Add an optional param (only if value is non-null).
  void addOptionalParam(String key, String? value) {
    if (value != null) addParam(key, value);
  }

  /// Add an optional int param (only if value is non-null).
  void addOptionalIntParam(String key, int? value) {
    if (value != null) addParam(key, value.toString());
  }
}

part of models;

/// NWC Info Event (NIP-47 kind 13194)
/// Published by wallet service to indicate which capabilities it supports
class NwcInfo extends ReplaceableModel<NwcInfo> {
  NwcInfo.fromMap(super.map, super.ref) : super.fromMap();

  /// List of supported NWC methods (space-separated in content)
  List<String> get supportedMethods {
    if (event.content.isEmpty) return [];
    return event.content
        .split(' ')
        .where((method) => method.isNotEmpty)
        .toList();
  }

  /// List of supported notification types from notifications tag
  List<String> get supportedNotifications {
    final notificationsTag = event.getFirstTagValue('notifications');
    if (notificationsTag == null) return [];
    return notificationsTag
        .split(' ')
        .where((notification) => notification.isNotEmpty)
        .toList();
  }

  /// Check if a specific method is supported
  bool supportsMethod(String method) {
    return supportedMethods.contains(method);
  }

  /// Check if a specific notification type is supported
  bool supportsNotification(String notification) {
    return supportedNotifications.contains(notification);
  }

  /// Common NWC methods
  static const String payInvoice = 'pay_invoice';
  static const String multiPayInvoice = 'multi_pay_invoice';
  static const String payKeysend = 'pay_keysend';
  static const String multiPayKeysend = 'multi_pay_keysend';
  static const String makeInvoice = 'make_invoice';
  static const String lookupInvoice = 'lookup_invoice';
  static const String listTransactions = 'list_transactions';
  static const String getBalance = 'get_balance';
  static const String getInfo = 'get_info';

  /// Common notification types
  static const String paymentReceived = 'payment_received';
  static const String paymentSent = 'payment_sent';
}

/// Generated partial model mixin for NwcInfo
mixin PartialNwcInfoMixin on ReplaceablePartialModel<NwcInfo> {
  /// Set supported methods (will be joined with spaces in content)
  set supportedMethods(List<String> methods) {
    event.content = methods.join(' ');
  }

  /// Set supported notifications (will be added as notifications tag)
  set supportedNotifications(List<String> notifications) {
    if (notifications.isNotEmpty) {
      event.setTagValue('notifications', notifications.join(' '));
    } else {
      event.removeTag('notifications');
    }
  }
}

/// Partial model for creating NwcInfo events
class PartialNwcInfo extends ReplaceablePartialModel<NwcInfo>
    with PartialNwcInfoMixin {
  PartialNwcInfo.fromMap(super.map) : super.fromMap();

  PartialNwcInfo({
    List<String> supportedMethods = const [],
    List<String> supportedNotifications = const [],
    DateTime? createdAt,
  }) {
    if (createdAt != null) {
      event.createdAt = createdAt;
    }
    this.supportedMethods = supportedMethods;
    this.supportedNotifications = supportedNotifications;
  }
}

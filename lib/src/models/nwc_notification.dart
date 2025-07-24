part of models;

/// NWC Notification Event (NIP-47 kind 23196)
/// Encrypted notification from wallet service to client about wallet events
class NwcNotification extends EphemeralModel<NwcNotification> {
  NwcNotification.fromMap(super.map, super.ref) : super.fromMap();

  /// The client public key this notification is directed to
  String get clientPubkey {
    final pTag = event.getFirstTagValue('p');
    if (pTag == null) {
      throw Exception('NWC notification missing client pubkey (p tag)');
    }
    return pTag;
  }

  /// Encrypted content (decrypt with NIP-04 to get actual notification)
  String get encryptedContent => event.content;

  /// Decrypt the content using the provided signer
  /// Returns a map with 'notification_type' and 'notification' fields
  Future<Map<String, dynamic>> decryptContent(Signer signer) async {
    final decryptedJson = await signer.nip04Decrypt(
      event.content,
      clientPubkey,
    );
    final decoded = jsonDecode(decryptedJson) as Map<String, dynamic>;

    // Validate required fields
    if (!decoded.containsKey('notification_type')) {
      throw Exception(
        'NWC notification missing required "notification_type" field',
      );
    }

    return decoded;
  }

  /// Get the notification type from decrypted content (requires signer)
  Future<String> getNotificationType(Signer signer) async {
    final content = await decryptContent(signer);
    return content['notification_type'] as String;
  }

  /// Get the notification data from decrypted content (requires signer)
  Future<Map<String, dynamic>?> getNotification(Signer signer) async {
    final content = await decryptContent(signer);
    return content['notification'] as Map<String, dynamic>?;
  }

  /// Check if this is a payment received notification (requires signer)
  Future<bool> isPaymentReceived(Signer signer) async {
    final type = await getNotificationType(signer);
    return type == NwcInfo.paymentReceived;
  }

  /// Check if this is a payment sent notification (requires signer)
  Future<bool> isPaymentSent(Signer signer) async {
    final type = await getNotificationType(signer);
    return type == NwcInfo.paymentSent;
  }
}

/// Partial model for creating NwcNotification events
class PartialNwcNotification extends EphemeralPartialModel<NwcNotification> {
  PartialNwcNotification.fromMap(super.map) : super.fromMap();

  PartialNwcNotification({
    required String clientPubkey,
    required String notificationType,
    required Map<String, dynamic> notification,
    DateTime? createdAt,
  }) {
    if (createdAt != null) {
      event.createdAt = createdAt;
    }

    // Add client pubkey as p tag
    event.setTagValue('p', clientPubkey);

    // Create the notification JSON
    final notificationData = <String, dynamic>{
      'notification_type': notificationType,
      'notification': notification,
    };

    // Content will be encrypted when signing
    event.content = jsonEncode(notificationData);
  }

  /// Create a payment received notification
  PartialNwcNotification.paymentReceived({
    required String clientPubkey,
    required String invoice,
    required String preimage,
    required String paymentHash,
    required int amount,
    String? description,
    String? descriptionHash,
    int? feesPaid,
    int? createdAtTimestamp,
    int? expiresAtTimestamp,
    int? settledAtTimestamp,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) : this(
         clientPubkey: clientPubkey,
         notificationType: NwcInfo.paymentReceived,
         notification: {
           'type': 'incoming',
           'invoice': invoice,
           'preimage': preimage,
           'payment_hash': paymentHash,
           'amount': amount,
           if (description != null) 'description': description,
           if (descriptionHash != null) 'description_hash': descriptionHash,
           if (feesPaid != null) 'fees_paid': feesPaid,
           if (createdAtTimestamp != null) 'created_at': createdAtTimestamp,
           if (expiresAtTimestamp != null) 'expires_at': expiresAtTimestamp,
           if (settledAtTimestamp != null) 'settled_at': settledAtTimestamp,
           if (metadata != null) 'metadata': metadata,
         },
         createdAt: createdAt,
       );

  /// Create a payment sent notification
  PartialNwcNotification.paymentSent({
    required String clientPubkey,
    required String preimage,
    required String paymentHash,
    required int amount,
    String? invoice,
    String? description,
    String? descriptionHash,
    int? feesPaid,
    int? createdAtTimestamp,
    int? expiresAtTimestamp,
    int? settledAtTimestamp,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) : this(
         clientPubkey: clientPubkey,
         notificationType: NwcInfo.paymentSent,
         notification: {
           'type': 'outgoing',
           if (invoice != null) 'invoice': invoice,
           'preimage': preimage,
           'payment_hash': paymentHash,
           'amount': amount,
           if (description != null) 'description': description,
           if (descriptionHash != null) 'description_hash': descriptionHash,
           if (feesPaid != null) 'fees_paid': feesPaid,
           if (createdAtTimestamp != null) 'created_at': createdAtTimestamp,
           if (expiresAtTimestamp != null) 'expires_at': expiresAtTimestamp,
           if (settledAtTimestamp != null) 'settled_at': settledAtTimestamp,
           if (metadata != null) 'metadata': metadata,
         },
         createdAt: createdAt,
       );
}

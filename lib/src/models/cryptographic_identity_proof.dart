import '../core/model.dart';
import '../utils/extensions.dart';

/// A NIP-C1 cryptographic identity proof (kind 30509).
///
/// For APKs, the identifier is the SHA-256 hash of the DER-encoded signing
/// certificate. The proof event links that certificate identity to a Nostr
/// pubkey.
class CryptographicIdentityProof
    extends ParameterizableReplaceableModel<CryptographicIdentityProof> {
  CryptographicIdentityProof.fromMap(super.map, super.ref) : super.fromMap();

  /// SHA-256 hash of the APK signing certificate.
  String get certificateHash => event.identifier;

  /// Base64 signature over the NIP-C1 proof message.
  String? get signature => event.getFirstTagValue('signature');

  /// Time after which the proof should no longer be trusted.
  DateTime? get expiry => event.getFirstTagValue('expiry')?.toInt()?.toDate();

  /// Optional revocation reason.
  String? get revokedReason => event.getFirstTagValue('revoked');

  bool get isRevoked => event.containsTag('revoked');

  bool get isExpired {
    final expiresAt = expiry;
    return expiresAt == null || !DateTime.now().isBefore(expiresAt);
  }

  bool get isActive => !isRevoked && !isExpired;
}

/// Create and sign NIP-C1 cryptographic identity proof events.
class PartialCryptographicIdentityProof
    extends ParameterizableReplaceablePartialModel<CryptographicIdentityProof> {
  PartialCryptographicIdentityProof.fromMap(super.map) : super.fromMap();

  PartialCryptographicIdentityProof({
    required String certificateHash,
    required String signature,
    required DateTime expiry,
  }) {
    identifier = certificateHash;
    this.signature = signature;
    this.expiry = expiry;
  }

  String? get certificateHash => event.getFirstTagValue('d');
  set certificateHash(String? value) => event.setTagValue('d', value);

  String? get signature => event.getFirstTagValue('signature');
  set signature(String? value) => event.setTagValue('signature', value);

  DateTime? get expiry => event.getFirstTagValue('expiry')?.toInt()?.toDate();
  set expiry(DateTime? value) =>
      event.setTagValue('expiry', value?.toSeconds().toString());

  void revoke([String? reason]) => event.setTagValue('revoked', reason ?? '');
}

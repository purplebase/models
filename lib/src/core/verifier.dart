part of models;

abstract class Verifier {
  bool verify(Map<String, dynamic> map);
}

class DartVerifier extends Verifier {
  @override
  bool verify(Map<String, dynamic> map) {
    bool verified = false;
    if (map['sig'] != null && map['sig'] != '') {
      verified = bip340.verify(map['pubkey'], map['id'], map['sig']);
      if (!verified) {
        print(
          '[purplebase] WARNING: Event ${map['id']} has an invalid signature',
        );
      }
    }
    return verified;
  }
}

final verifierProvider = Provider<Verifier>((_) => DartVerifier());

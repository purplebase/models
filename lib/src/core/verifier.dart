import 'package:bip340/bip340.dart' as bip340;
import 'package:riverpod/riverpod.dart';

import '../utils/utils.dart';

abstract class Verifier {
  bool verify(Map<String, dynamic> map);
}

class DartVerifier extends Verifier {
  @override
  bool verify(Map<String, dynamic> map) {
    final sig = map['sig'];
    if (sig == null || sig == '') {
      return false;
    }

    // A valid sig over the claimed id proves nothing if the id no longer
    // matches the serialized event (e.g. a tampered kind or content).
    String recomputedId;
    try {
      recomputedId = Utils.getEventIdFromMap(map);
    } catch (_) {
      return false;
    }
    if (recomputedId != map['id']) {
      print('[models] WARNING: Event ${map['id']} has a mismatched id');
      return false;
    }

    final verified = bip340.verify(map['pubkey'], map['id'], sig as String);
    if (!verified) {
      print(
        '[models] WARNING: Event ${map['id']} has an invalid signature',
      );
    }
    return verified;
  }
}

final verifierProvider = Provider<Verifier>((_) => DartVerifier());

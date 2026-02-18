import 'package:riverpod/riverpod.dart';

import '../models/profile.dart';
import '../signer/signer.dart';
import '../source/source.dart';
import 'query_providers.dart';

// Internal state providers
final _signerProvider = StateProvider.family<Signer?, String>(
  (_, pubkey) => null,
);

final _signedInPubkeysProvider = StateProvider<Set<String>>((_) => {});

final _activePubkeyProvider = StateProvider<String?>((_) => null);

/// Returns a Signer given a pubkey.
final signerProvider = Provider.family<Signer?, String>(
  (ref, pubkey) => ref.watch(_signerProvider(pubkey)),
);

/// Returns all currently signed in pubkeys.
final signedInPubkeysProvider = Provider(
  (ref) => ref.watch(_signedInPubkeysProvider),
);

/// Returns the active pubkey.
final activePubkeyProvider = Provider(
  (ref) => ref.watch(_activePubkeyProvider),
);

/// Returns the active signer.
final activeSignerProvider = Provider((ref) {
  final activePubkey = ref.watch(_activePubkeyProvider);
  if (activePubkey == null) return null;
  return ref.read(_signerProvider(activePubkey));
});

/// Returns the profile for the active signer.
final activeProfileProvider = Provider.family<Profile?, Source>((
  ref,
  source,
) {
  final activePk = ref.watch(_activePubkeyProvider);
  if (activePk == null) return null;
  final state = ref.watch(
    query<Profile>(authors: {activePk}, source: source, limit: 1),
  );
  return state.models.firstOrNull;
});

/// Extension to add Riverpod-aware signIn/signOut to Signer.
extension SignerProviderExtension on Signer {
  /// Sign in this signer, registering it in the provider graph.
  Future<void> signIn(
    Ref ref, {
    bool setAsActive = true,
    bool registerSigner = true,
  }) async {
    if (!isSignedIn) {
      throw UnsupportedError(
        'Pubkey must be set before signIn. Call initialize() first.',
      );
    }

    if (!registerSigner) return;

    ref.read(_signerProvider(pubkey).notifier).state = this;
    ref.read(_signedInPubkeysProvider.notifier).state =
        ref.read(_signedInPubkeysProvider)..add(pubkey);

    if (setAsActive) {
      setAsActivePubkey(ref);
    }
  }

  /// Sign out this signer.
  Future<void> signOut(Ref ref) async {
    ref.read(_signedInPubkeysProvider.notifier).state =
        ref.read(_signedInPubkeysProvider)..remove(pubkey);
    removeAsActivePubkey(ref);
  }

  /// Set this signer as the active pubkey.
  void setAsActivePubkey(Ref ref) {
    ref.read(_activePubkeyProvider.notifier).state = pubkey;
  }

  /// Remove this signer as the active pubkey if it's currently active.
  void removeAsActivePubkey(Ref ref) {
    if (ref.read(_activePubkeyProvider) == pubkey) {
      ref.read(_activePubkeyProvider.notifier).state = null;
    }
  }
}

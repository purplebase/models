import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';

import '../core/model.dart';
import '../models/profile.dart';
import '../source/source.dart';
import '../storage/storage_notifier.dart';
import '../providers/query_providers.dart';

/// Base class for all Nostr event signers.
///
/// Models are pure data (use [StorageReader] for construction).
/// Signers need [Ref] for provider integration (signIn/signOut).
abstract class Signer {
  final Ref ref;

  String? _pubkey;

  /// The public key (in hex format) associated with this signer.
  String get pubkey => _pubkey!;

  @protected
  void internalSetPubkey(String pubkey) => _pubkey = pubkey;

  Signer(this.ref);

  /// The storage reader for model construction during signing.
  StorageReader get reader => ref.read(storageNotifierProvider.notifier);

  /// Check if this signer is available for use.
  Future<bool> get isAvailable async => true;

  /// Whether this signer is signed in
  bool get isSignedIn => _pubkey != null;

  /// Initialize the signer (derive pubkey, etc).
  /// Subclasses must call this or [internalSetPubkey] before [signIn].
  Future<void> initialize();

  /// Sign in this signer, registering it in the Riverpod provider graph.
  @mustCallSuper
  Future<void> signIn({
    bool setAsActive = true,
    bool registerSigner = true,
  }) async {
    if (_pubkey == null) {
      throw UnsupportedError(
        'Pubkey must be set, bug in $runtimeType implementation',
      );
    }

    if (!registerSigner) return;

    ref.read(_signerStateProvider(_pubkey!).notifier).state = this;
    ref.read(_signedInPubkeysStateProvider.notifier).state =
        ref.read(_signedInPubkeysStateProvider)..add(_pubkey!);

    if (setAsActive) {
      setAsActivePubkey();
    }
  }

  /// Sign out this signer.
  Future<void> signOut() async {
    ref.read(_signedInPubkeysStateProvider.notifier).state =
        ref.read(_signedInPubkeysStateProvider)..remove(_pubkey);
    removeAsActivePubkey();
    _pubkey = null;
  }

  /// Set this signer as the active pubkey.
  void setAsActivePubkey() {
    ref.read(_activePubkeyStateProvider.notifier).state = _pubkey;
  }

  /// Remove this signer as the active pubkey if it's currently active.
  void removeAsActivePubkey() {
    if (ref.read(_activePubkeyStateProvider) == _pubkey) {
      ref.read(_activePubkeyStateProvider.notifier).state = null;
    }
  }

  /// Sign the partial models.
  Future<List<E>> sign<E extends Model<dynamic>>(
    List<PartialModel<Model<dynamic>>> partialModels,
  );

  /// NIP-04: Encrypt
  Future<String> nip04Encrypt(String message, String recipientPubkey);

  /// NIP-04: Decrypt
  Future<String> nip04Decrypt(String encryptedMessage, String senderPubkey);

  /// NIP-44: Encrypt
  Future<String> nip44Encrypt(String message, String recipientPubkey);

  /// NIP-44: Decrypt
  Future<String> nip44Decrypt(String encryptedMessage, String senderPubkey);

  // --- Internal state providers ---

  static final _signerStateProvider = StateProvider.family<Signer?, String>(
    (_, pubkey) => null,
  );
  static final _signedInPubkeysStateProvider =
      StateProvider<Set<String>>((_) => {});
  static final _activePubkeyStateProvider = StateProvider<String?>((_) => null);

  // --- Public providers ---

  /// Returns a Signer given a pubkey.
  static final signerProvider = Provider.family<Signer?, String>(
    (ref, pubkey) => ref.watch(_signerStateProvider(pubkey)),
  );

  /// Returns all currently signed in pubkeys.
  static final signedInPubkeysProvider = Provider(
    (ref) => ref.watch(_signedInPubkeysStateProvider),
  );

  /// Returns the active pubkey.
  static final activePubkeyProvider = Provider(
    (ref) => ref.watch(_activePubkeyStateProvider),
  );

  /// Returns the active signer.
  static final activeSignerProvider = Provider((ref) {
    final activePubkey = ref.watch(_activePubkeyStateProvider);
    if (activePubkey == null) return null;
    return ref.read(_signerStateProvider(activePubkey));
  });

  /// Returns the profile for the active signer.
  static final activeProfileProvider =
      Provider.family<Profile?, Source>((ref, source) {
    final activePubkey = ref.watch(_activePubkeyStateProvider);
    if (activePubkey == null) return null;
    final state = ref.watch(
      query<Profile>(authors: {activePubkey}, source: source, limit: 1),
    );
    return state.models.firstOrNull;
  });
}

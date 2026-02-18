import 'package:riverpod/riverpod.dart';

import '../storage/storage_notifier.dart';
import '../storage/storage_configuration.dart';

/// Initialization provider that MUST be called from any client application
/// with a [StorageConfiguration].
final initializationProvider =
    FutureProvider.family<void, StorageConfiguration>((ref, config) async {
  await ref.read(storageNotifierProvider.notifier).initialize(config);
});

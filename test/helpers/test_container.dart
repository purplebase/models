import 'dart:async';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

/// Provider to access ref in tests
final refProvider = Provider((ref) => ref);

/// Extension on ProviderContainer for common test operations
extension TestContainerExt on ProviderContainer {
  /// Get the storage notifier as DummyStorageNotifier
  DummyStorageNotifier get storage =>
      read(storageNotifierProvider.notifier) as DummyStorageNotifier;

  /// Get ref for model construction
  Ref get ref => read(refProvider);

  /// Clear storage and dispose container
  Future<void> tearDown() async {
    await storage.clear();
    dispose();
  }

  /// Create a tester for state notifier providers
  StateNotifierProviderTester testerFor(
    AutoDisposeStateNotifierProvider provider,
  ) {
    // Keep the provider alive during the test
    listen(provider, (_, __) {}).read();
    return StateNotifierProviderTester(read(provider.notifier));
  }

  /// Create a tester for regular providers
  ProviderTester testerForProvider(Provider provider) {
    return ProviderTester(this, provider);
  }
}

/// Creates a configured ProviderContainer for testing.
///
/// Each container has its own isolated in-memory storage,
/// so tests can run in parallel.
///
/// Note: [requestBufferDuration] and [streamingBufferDuration] are set to
/// [Duration.zero] by default for predictable test behavior, unless
/// explicitly overridden in the passed [config].
Future<ProviderContainer> createTestContainer({
  StorageConfiguration? config,
  List<Override>? overrides,
}) async {
  final container = ProviderContainer(overrides: [
    storageNotifierProvider.overrideWith((ref) => DummyStorageNotifier(ref)),
    ...?overrides,
  ]);

  final storageConfig = StorageConfiguration(
    databasePath: config?.databasePath,
    keepSignatures: config?.keepSignatures ?? false,
    skipVerification: config?.skipVerification ?? false,
    defaultRelays: config?.defaultRelays ?? {'default': {'wss://test.relay'}},
    defaultQuerySource:
        config?.defaultQuerySource ?? const LocalAndRemoteSource(stream: false),
    idleTimeout: config?.idleTimeout ?? const Duration(minutes: 5),
    responseTimeout: config?.responseTimeout ?? const Duration(seconds: 4),
    streamingBufferDuration: config?.streamingBufferDuration ?? Duration.zero,
    keepMaxModels: config?.keepMaxModels ?? 1000,
    requestBufferDuration: config?.requestBufferDuration ?? Duration.zero,
  );

  await container.read(initializationProvider(storageConfig).future);

  return container;
}

/// Helper for testing state notifier emissions.
///
/// Tracks state changes from a StateNotifier and provides methods
/// to assert on emitted states. Handles the asynchronous nature of
/// RequestNotifier state transitions with DummyStorage.
class StateNotifierProviderTester {
  final StateNotifier notifier;

  final _disposeFns = <void Function()>[];
  final _states = <dynamic>[];
  final _stateControllers = <Completer>[];
  var i = 0;

  StateNotifierProviderTester(this.notifier) {
    final dispose = notifier.addListener((state) {
      _states.add(state);
      for (final c in _stateControllers) {
        if (!c.isCompleted) c.complete();
      }
    }, fireImmediately: false);
    _disposeFns.add(dispose);
  }

  /// Wait for the next state that matches the matcher.
  /// Skips intermediate states (like StorageLoading) that don't match.
  Future<dynamic> expect(Matcher m, {Duration timeout = const Duration(seconds: 5)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      // Check any already-received states
      while (i < _states.length) {
        final state = _states[i];
        i++;
        try {
          expectLater(state, m);
          return state;
        } catch (_) {
          // State doesn't match, try next
        }
      }
      await Future(() {});
      if (i < _states.length) continue;
      // Wait for more states with a short timeout
      final completer = Completer();
      _stateControllers.add(completer);
      await completer.future.timeout(
        Duration(milliseconds: 50),
        onTimeout: () => null,
      );
      _stateControllers.remove(completer);
    }
    // Final check with assertion
    while (i < _states.length) {
      final state = _states[i];
      i++;
      expectLater(state, m);
      return state;
    }
    throw TestFailure('Timed out waiting for state matching $m. '
        'Received states: ${_states.skip(i > _states.length ? 0 : i)}');
  }

  /// Expect StorageData with matching models (query is complete)
  Future<dynamic> expectData(Matcher m) async {
    return expect(isA<StorageData>().having((s) => s.models, 'models', m));
  }

  /// Expect any state (StorageLoading or StorageData) with matching models.
  Future<dynamic> expectModels(Matcher m) async {
    return expect(isA<StorageState>().having((s) => s.models, 'models', m));
  }

  void dispose() {
    for (final fn in _disposeFns) {
      fn.call();
    }
  }
}

/// Helper for testing regular provider emissions
class ProviderTester {
  final _disposeFns = <void Function()>[];
  final _completers = <Completer>[Completer()];
  var i = 0;

  ProviderTester(ProviderContainer container, Provider provider) {
    final subscription = container.listen(provider, (previous, next) {
      _completers.last.complete(next);
      _completers.add(Completer());
    });

    _disposeFns.add(() => subscription.close());
  }

  Future<dynamic> expect(Matcher m) async {
    final result = await expectLater(_completers[i].future, completion(m));
    i++;
    return result;
  }

  /// Expect StorageData with matching models (query is complete)
  Future<dynamic> expectData(Matcher m) async {
    return expect(isA<StorageData>().having((s) => s.models, 'models', m));
  }

  /// Expect any state (StorageLoading or StorageData) with matching models.
  Future<dynamic> expectModels(Matcher m) async {
    return expect(isA<StorageState>().having((s) => s.models, 'models', m));
  }

  void dispose() {
    for (final fn in _disposeFns) {
      fn.call();
    }
  }
}

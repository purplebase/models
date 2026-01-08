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
Future<ProviderContainer> createTestContainer({
  StorageConfiguration? config,
  List<Override>? overrides,
}) async {
  final container = ProviderContainer(overrides: overrides ?? []);
  final storageConfig = config ??
      StorageConfiguration(
        defaultRelays: {
          'default': {'wss://test.relay'},
        },
        streamingBufferWindow: Duration.zero,
        keepMaxModels: 1000,
      );

  await container.read(initializationProvider(storageConfig).future);

  return container;
}

/// Helper for testing state notifier emissions
class StateNotifierProviderTester {
  final StateNotifier notifier;

  final _disposeFns = <void Function()>[];
  final _completers = <Completer>[Completer()];
  var i = 0;

  StateNotifierProviderTester(this.notifier) {
    final dispose = notifier.addListener((state) {
      _completers.last.complete(state);
      _completers.add(Completer());
    }, fireImmediately: false);
    _disposeFns.add(dispose);
  }

  Future<dynamic> expect(Matcher m) async {
    final result = await expectLater(_completers[i].future, completion(m));
    i++;
    return result;
  }

  Future<dynamic> expectModels(Matcher m) async {
    return expect(isA<StorageData>().having((s) => s.models, 'models', m));
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

  Future<dynamic> expectModels(Matcher m) async {
    return expect(isA<StorageData>().having((s) => s.models, 'models', m));
  }

  void dispose() {
    for (final fn in _disposeFns) {
      fn.call();
    }
  }
}


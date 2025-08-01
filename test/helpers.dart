import 'dart:async';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

final nielPubkey =
    'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be';
final verbirichaPubkey =
    '7fa56f5d6962ab1e3cd424e758c3002b8665f7b0d8dcee9fe9e288d7751ac194';
final franzapPubkey =
    '726a1e261cc6474674e8285e3951b3bb139be9a773d1acf49dc868db861a1c11';

class StateNotifierProviderTester {
  final StateNotifier notifier;

  final _disposeFns = <void Function()>[];
  final _completers = <Completer>[Completer()];
  var initial = true;
  var i = 0;

  StateNotifierProviderTester(this.notifier) {
    final dispose = notifier.addListener((state) {
      // print('${state.runtimeType} ${state.models.length}');
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

  dispose() {
    for (final fn in _disposeFns) {
      fn.call();
    }
  }
}

class ProviderTester {
  final _disposeFns = <void Function()>[];
  final _completers = <Completer>[Completer()];
  var initial = true;
  var i = 0;

  /// Creates a tester from a Provider
  ProviderTester(ProviderContainer container, Provider provider) {
    // Keep the provider alive and listen to changes
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

  dispose() {
    for (final fn in _disposeFns) {
      fn.call();
    }
  }
}

extension AutoDisposeProviderContainerExt on ProviderContainer {
  StateNotifierProviderTester testerFor(
    AutoDisposeStateNotifierProvider provider,
  ) {
    // Keep the provider alive during the test
    listen(provider, (_, __) {}).read();

    return StateNotifierProviderTester(read(provider.notifier));
  }
}

extension ProviderContainerExt on ProviderContainer {
  ProviderTester testerForProvider(Provider provider) {
    return ProviderTester(this, provider);
  }
}

final refProvider = Provider((ref) => ref);

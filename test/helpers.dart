import 'dart:async';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

final niel = 'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be';
final verbiricha =
    '7fa56f5d6962ab1e3cd424e758c3002b8665f7b0d8dcee9fe9e288d7751ac194';
final franzap =
    '726a1e261cc6474674e8285e3951b3bb139be9a773d1acf49dc868db861a1c11';

class StorageNotifierTester {
  final RequestNotifier notifier;

  final _disposeFns = [];
  final completers = <Completer>[Completer()];
  var initial = true;
  var i = 0;

  StorageNotifierTester(this.notifier) {
    final dispose = notifier.addListener((state) {
      // print('${state.runtimeType} ${state.models.length}');
      completers.last.complete(state);
      completers.add(Completer());
    }, fireImmediately: false);
    _disposeFns.add(dispose);
  }

  Future<dynamic> expect(Matcher m) async {
    final result = await expectLater(completers[i].future, completion(m));
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

extension ProviderContainerExt on ProviderContainer {
  /// Has fireImmediately set to false, so the
  /// initial StorageLoading never gets fired
  StorageNotifierTester testerFor(
      AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>
          provider) {
    // Keep the provider alive during the test
    listen(provider, (_, __) {}).read();

    return StorageNotifierTester(read(provider.notifier));
  }
}

final refProvider = Provider((ref) => ref);

final dummySigner = DummySigner();

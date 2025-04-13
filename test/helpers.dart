import 'dart:async';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

final niel = 'npub149p5act9a5qm9p47elp8w8h3wpwn2d7s2xecw2ygnrxqp4wgsklq9g722q';
final verbiricha =
    'npub107jk7htfv243u0x5ynn43scq9wrxtaasmrwwa8lfu2ydwag6cx2quqncxg';
final franzap =
    'npub1wf4pufsucer5va8g9p0rj5dnhvfeh6d8w0g6eayaep5dhps6rsgs43dgh9';

class StorageNotifierTester {
  final RequestNotifier notifier;

  final _disposeFns = [];
  final completers = <Completer>[Completer()];
  var initial = true;
  var i = 0;

  StorageNotifierTester(this.notifier) {
    final dispose = notifier.addListener((state) {
      print('${state.runtimeType} ${state.models.length}');
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

import 'dart:async';

import 'package:models/models.dart';
import 'package:test/test.dart';

class RelayNotifierTester {
  final RelayNotifier notifier;

  final _disposeFns = [];
  var completer = Completer();
  var initial = true;

  RelayNotifierTester(this.notifier, {bool fireImmediately = false}) {
    final dispose = notifier.addListener((state) {
      // print('received: ${state.models}');
      if (fireImmediately && initial) {
        Future.microtask(() {
          completer.complete(state);
          completer = Completer();
          initial = false;
        });
      } else {
        completer.complete(state);
        completer = Completer();
      }
    }, fireImmediately: fireImmediately);
    _disposeFns.add(dispose);
  }

  Future<void> expect(Matcher m) async {
    return expectLater(completer.future, completion(m));
  }

  dispose() {
    for (final fn in _disposeFns) {
      fn.call();
    }
  }
}

import 'dart:async';

import 'package:models/models.dart';
import 'package:models/src/storage/dummy.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

class StorageNotifierTester {
  final RequestNotifier notifier;

  final _disposeFns = [];
  var completer = Completer();
  var initial = true;

  StorageNotifierTester(this.notifier, {bool fireImmediately = false}) {
    final dispose = notifier.addListener((state) {
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

  Future<dynamic> expect(Matcher m) async {
    return expectLater(completer.future, completion(m));
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
  StorageNotifierTester testerFor(
          AutoDisposeStateNotifierProvider<RequestNotifier, StorageState>
              provider,
          {bool fireImmediately = false}) =>
      StorageNotifierTester(read(provider.notifier),
          fireImmediately: fireImmediately);
}

extension PartialEventExt<E extends Event<E>> on PartialEvent<E> {
  Future<E> by(String pubkey) {
    return signWith(dummySigner, withPubkey: pubkey);
  }
}

/// Runs code in a separate dimension that compresses time
Zone getFastTimerZone() {
  return Zone.current.fork(
    specification: ZoneSpecification(
      // Regular timers complete immediately
      createTimer: (Zone self, ZoneDelegate parent, Zone zone,
          Duration duration, void Function() f) {
        return parent.createTimer(zone, Duration.zero, f);
      },

      // Periodic timers fire at 1ms intervals for speed while maintaining periodic behavior
      createPeriodicTimer: (Zone self, ZoneDelegate parent, Zone zone,
          Duration period, void Function(Timer) f) {
        return parent.createPeriodicTimer(zone, Duration(milliseconds: 1), f);
      },
    ),
  );
}

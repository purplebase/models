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
      AutoDisposeStateNotifierProvider<RequestNotifier, StorageState> provider,
      {bool fireImmediately = false}) {
    // Keep the provider alive during the test
    listen(provider, (_, __) {}).read();

    return StorageNotifierTester(read(provider.notifier),
        fireImmediately: fireImmediately);
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

// Run

T runSynchronously<T>(Future<T> Function() asyncFunction) {
  final completer = Completer<T>();

  // Create a synchronous zone
  final zone = Zone.current.fork(
      specification: ZoneSpecification(
          // Intercept all scheduleMicrotask calls
          scheduleMicrotask: (self, parent, zone, task) {
    task(); // Execute the microtask immediately
  },
          // Handle Timer creation
          createTimer: (self, parent, zone, duration, callback) {
    if (duration == Duration.zero) {
      callback(); // Execute immediately for zero-duration timers
      return Timer(Duration.zero, () {}); // Return a dummy timer
    }
    return parent.createTimer(zone, duration, callback);
  }));

  // Run the async function in our custom zone
  zone.runGuarded(() {
    asyncFunction().then((value) {
      completer.complete(value);
    }).catchError((error, stackTrace) {
      completer.completeError(error, stackTrace);
    });

    // Process all pending events in the event queue
    _drainMicrotaskQueue();
  });

  // If the completer hasn't completed yet, it means we can't make this synchronous
  if (!completer.isCompleted) {
    throw UnsupportedError(
        'Cannot run this async function synchronously as it likely uses I/O or other truly async operations');
  }

  return completer.future.sync();
}

// Helper function to drain the microtask queue
void _drainMicrotaskQueue() {
  // This technique forces processing of the microtask queue
  // but will still fail for true async operations like I/O
  scheduleMicrotask(() {});
}

// Extension on Future to get the result synchronously
extension SyncFuture<T> on Future<T> {
  T sync() {
    T? result;
    bool isDone = false;
    bool hasError = false;
    dynamic error;

    whenComplete(() {
      isDone = true;
    });

    then((value) {
      result = value;
    }).catchError((e) {
      hasError = true;
      error = e;
      throw e;
    });

    // Wait for future to complete
    while (!isDone) {
      _drainMicrotaskQueue();
    }

    // If there was an error, throw it
    if (hasError) {
      throw error;
    }

    // Return the result, with null check
    if (result == null && null is! T) {
      throw StateError(
          'Future completed with null when non-nullable type was expected');
    }

    return result as T;
  }
}

final refProvider = Provider((ref) => ref);

final dummySigner = DummySigner();

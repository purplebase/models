import 'dart:async';

/// Runs an async function synchronously by executing it in a special zone
/// that processes microtasks immediately.
///
/// **NOTE**: This utility is ONLY used by the dummy implementation's dummySign()
/// method. Production signers use proper async signing. This is safe because
/// dummySign() prepareForSigning hooks in the dummy signer don't involve
/// real I/O or Timers - they complete via microtasks.
///
/// **WARNING**: This is a testing utility and has significant limitations:
/// - Only works for async operations that complete via microtasks
/// - Does NOT work for Timers, IO operations, or truly async operations
/// - Will throw if the operation doesn't complete synchronously
/// - Only intended for testing purposes
///
/// This works by intercepting `scheduleMicrotask` calls in a custom Zone
/// and executing them immediately instead of queuing them.
///
/// Example:
/// ```dart
/// final result = runSync(() async {
///   return await Future.value(42);
/// });
/// print(result); // 42
/// ```
T runSync<T>(Future<T> Function() fn) {
  T? result;
  Object? error;
  StackTrace? stackTrace;
  var completed = false;

  // Create a zone that executes microtasks immediately and catches errors
  runZoned(
    () {
      try {
        fn().then<void>(
          (value) {
            result = value;
            completed = true;
          },
          onError: (e, st) {
            error = e;
            stackTrace = st;
            completed = true;
          },
        );
      } catch (e, st) {
        // Catch synchronous errors thrown by fn()
        error = e;
        stackTrace = st;
        completed = true;
      }
    },
    zoneSpecification: ZoneSpecification(
      scheduleMicrotask: (self, parent, zone, f) {
        // Execute microtasks immediately instead of queuing them
        try {
          f();
        } catch (e, st) {
          if (!completed) {
            error = e;
            stackTrace = st;
            completed = true;
          }
        }
      },
    ),
    onError: (e, st) {
      // Catch any uncaught errors in the zone
      if (!completed) {
        error = e;
        stackTrace = st;
        completed = true;
      }
    },
  );

  if (!completed) {
    throw StateError(
      'Async operation did not complete synchronously. '
      'This likely means it depends on Timers, IO, or other truly async operations. '
      'Consider using fake_async package for testing such code.',
    );
  }

  if (error != null) {
    Error.throwWithStackTrace(error!, stackTrace ?? StackTrace.current);
  }

  return result as T;
}

/// Alternative implementation that uses a slightly different zone approach.
/// This version might handle certain edge cases differently.
T runSyncRecursive<T>(Future<T> Function() fn) {
  T? result;
  Object? error;
  StackTrace? stackTrace;
  var completed = false;
  final microtasks = <void Function()>[];

  runZoned(
    () {
      try {
        fn().then<void>(
          (value) {
            result = value;
            completed = true;
          },
          onError: (e, st) {
            error = e;
            stackTrace = st;
            completed = true;
          },
        );
      } catch (e, st) {
        // Catch synchronous errors
        error = e;
        stackTrace = st;
        completed = true;
      }
    },
    zoneSpecification: ZoneSpecification(
      scheduleMicrotask: (self, parent, zone, f) {
        // Collect and execute microtasks
        microtasks.add(f);
        try {
          f();
        } catch (e, st) {
          if (!completed) {
            error = e;
            stackTrace = st;
            completed = true;
          }
        }
      },
    ),
    onError: (e, st) {
      if (!completed) {
        error = e;
        stackTrace = st;
        completed = true;
      }
    },
  );

  if (!completed) {
    throw StateError('Async operation did not complete synchronously.');
  }

  if (error != null) {
    Error.throwWithStackTrace(error!, stackTrace ?? StackTrace.current);
  }

  return result as T;
}

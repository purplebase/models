import 'package:models/src/utils/async.dart';
import 'package:test/test.dart';

void main() {
  group('runSync', () {
    test('should execute simple async function synchronously', () {
      final result = runSync(() async {
        return 42;
      });

      expect(result, equals(42));
    });

    test('should handle Future.value', () {
      final result = runSync(() async {
        return await Future.value('hello');
      });

      expect(result, equals('hello'));
    });

    test('should handle multiple awaits', () {
      final result = runSync(() async {
        final a = await Future.value(10);
        final b = await Future.value(20);
        return a + b;
      });

      expect(result, equals(30));
    });

    test('should handle nested async calls', () {
      Future<int> innerAsync() async {
        return await Future.value(5);
      }

      final result = runSync(() async {
        final value = await innerAsync();
        return value * 2;
      });

      expect(result, equals(10));
    });

    test('should propagate exceptions', () {
      expect(
        () => runSync(() async {
          throw Exception('test error');
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('should propagate exceptions with await', () {
      expect(
        () => runSync(() async {
          await Future.value(1);
          throw StateError('async error');
        }),
        throwsA(isA<StateError>()),
      );
    });

    test('should handle Future.error', () {
      expect(
        () => runSync(() async {
          return await Future<int>.error(ArgumentError('bad arg'));
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should work with complex data types', () {
      final result = runSync(() async {
        return {'key': 'value', 'count': 42};
      });

      expect(result, equals({'key': 'value', 'count': 42}));
    });

    test('should handle Future.microtask', () {
      final result = runSync(() async {
        return await Future.microtask(() => 'microtask result');
      });

      expect(result, equals('microtask result'));
    });

    test('should handle multiple Future.microtask', () {
      final result = runSync(() async {
        final a = await Future.microtask(() => 1);
        final b = await Future.microtask(() => 2);
        final c = await Future.microtask(() => 3);
        return a + b + c;
      });

      expect(result, equals(6));
    });

    test('should work with try-catch in async', () {
      final result = runSync(() async {
        try {
          await Future.value(1);
          throw Exception('caught');
        } catch (e) {
          return 'error handled';
        }
      });

      expect(result, equals('error handled'));
    });

    test('should handle null values', () {
      final result = runSync<String?>(() async {
        return null;
      });

      expect(result, isNull);
    });

    test('should handle empty Future', () {
      // Just verify it doesn't throw
      runSync<void>(() async {
        await Future.value();
      });

      // If we got here, it worked
      expect(true, isTrue);
    });

    // Note: These tests are expected to fail or timeout with truly async operations
    test(
      'should timeout with Future.delayed',
      () {
        expect(
          () => runSync(() async {
            // This uses a Timer, not a microtask, so it won't work
            return await Future.delayed(Duration.zero, () => 'delayed');
          }),
          throwsStateError,
        );
      },
      skip: 'Future.delayed uses Timers which cannot be executed synchronously',
    );
  });

  group('runSyncRecursive', () {
    test('should execute simple async function synchronously', () {
      final result = runSyncRecursive(() async {
        return 42;
      });

      expect(result, equals(42));
    });

    test('should handle multiple awaits', () {
      final result = runSyncRecursive(() async {
        final a = await Future.value(10);
        final b = await Future.value(20);
        return a + b;
      });

      expect(result, equals(30));
    });

    test('should propagate exceptions', () {
      expect(
        () => runSyncRecursive(() async {
          throw Exception('test error');
        }),
        throwsA(isA<Exception>()),
      );
    });
  });
}

import 'package:test/test.dart';
import 'package:models/models.dart';

void main() {
  group('Source Equatable', () {
    test('LocalSource instances are equal', () {
      const source1 = LocalSource();
      const source2 = LocalSource();
      expect(source1, equals(source2));
      expect(source1.hashCode, equals(source2.hashCode));
    });

    test('RemoteSource instances with same properties are equal', () {
      const source1 = RemoteSource(
        relays: 'social',
        stream: true,
      );
      const source2 = RemoteSource(
        relays: 'social',
        stream: true,
      );
      expect(source1, equals(source2));
      expect(source1.hashCode, equals(source2.hashCode));
    });

    test('RemoteSource instances with different stream are not equal', () {
      const source1 = RemoteSource(stream: true);
      const source2 = RemoteSource(stream: false);
      expect(source1, isNot(equals(source2)));
    });

    test('LocalAndRemoteSource instances with same properties are equal', () {
      const source1 = LocalAndRemoteSource(
        relays: 'social',
        stream: true,
      );
      const source2 = LocalAndRemoteSource(
        relays: 'social',
        stream: true,
      );
      expect(source1, equals(source2));
      expect(source1.hashCode, equals(source2.hashCode));
    });

    test(
      'RemoteSource and LocalAndRemoteSource with same properties are not equal',
      () {
        const source1 = RemoteSource(
          relays: 'social',
          stream: true,
        );
        const source2 = LocalAndRemoteSource(
          relays: 'social',
          stream: true,
        );
        // Different types, so should not be equal
        expect(source1, isNot(equals(source2)));
      },
    );

    test('RemoteSource with different relays are not equal', () {
      const source1 = RemoteSource(relays: 'wss://relay1.com');
      const source2 = RemoteSource(relays: 'wss://relay2.com');
      expect(source1, isNot(equals(source2)));
    });
  });

  group('Source copyWith', () {
    test('RemoteSource copyWith creates equal instance when no changes', () {
      const original = RemoteSource(
        relays: 'social',
        stream: true,
      );
      final copied = original.copyWith();
      expect(copied, equals(original));
      expect(copied.relays, equals('social'));
      expect(copied.stream, equals(true));
    });

    test('RemoteSource copyWith updates stream property', () {
      const original = RemoteSource(
        relays: 'social',
        stream: true,
      );
      final modified = original.copyWith(stream: false);

      expect(modified.relays, equals('social'));
      expect(modified.stream, equals(false));
      expect(modified, isNot(equals(original)));
    });

    test('RemoteSource copyWith updates multiple properties', () {
      const original = RemoteSource(
        relays: 'social',
        stream: true,
      );
      final modified = original.copyWith(relays: 'apps', stream: false);

      expect(modified.relays, equals('apps'));
      expect(modified.stream, equals(false));
    });

    test('RemoteSource copyWith updates relays', () {
      const original = RemoteSource(relays: 'wss://relay1.com');
      final modified = original.copyWith(relays: 'wss://relay2.com');

      expect(modified.relays, equals('wss://relay2.com'));
      expect(modified, isNot(equals(original)));
    });

    test('LocalAndRemoteSource copyWith preserves type', () {
      const original = LocalAndRemoteSource(
        relays: 'social',
        stream: true,
      );
      final copied = original.copyWith();

      // Should still be LocalAndRemoteSource
      expect(copied, isA<LocalAndRemoteSource>());
      expect(copied, equals(original));
    });

    test(
      'LocalAndRemoteSource copyWith updates properties and preserves type',
      () {
        const original = LocalAndRemoteSource(
          relays: 'social',
          stream: true,
        );
        final modified = original.copyWith(stream: false);

        expect(modified, isA<LocalAndRemoteSource>());
        expect(modified.stream, equals(false));
        expect(modified.relays, equals('social'));
      },
    );

    test('copyWith chain produces expected result', () {
      const original = RemoteSource();
      final result = original
          .copyWith(relays: 'social')
          .copyWith(stream: false);

      expect(result.relays, equals('social'));
      expect(result.stream, equals(false));
    });
  });

  group('Source type differentiation', () {
    test(
      'different Source types are not equal even with same underlying data',
      () {
        const remote = RemoteSource(stream: true);
        const localAndRemote = LocalAndRemoteSource(stream: true);
        const local = LocalSource();

        expect(remote, isNot(equals(localAndRemote)));
        expect(remote, isNot(equals(local)));
        expect(localAndRemote, isNot(equals(local)));
      },
    );
  });

  group('RelayList label vs URL detection', () {
    test('URL starting with wss:// is treated as ad-hoc relay', () {
      const source = RemoteSource(relays: 'wss://relay.example.com');
      expect(source.relays, startsWith('wss://'));
    });

    test('URL starting with ws:// is treated as ad-hoc relay', () {
      const source = RemoteSource(relays: 'ws://relay.example.com');
      expect(source.relays, startsWith('ws://'));
    });

    test('Non-URL string is treated as identifier', () {
      const source = RemoteSource(relays: 'AppCatalog');
      expect(source.relays, isNot(startsWith('ws')));
    });

    test('Null relays means outbox lookup (TODO)', () {
      const source = RemoteSource();
      expect(source.relays, isNull);
    });
  });

  group('Stream behavior', () {
    test('stream defaults to true', () {
      const source = RemoteSource();
      expect(source.stream, isTrue);
    });

    test('stream: true means fire-and-forget (events via callbacks)', () {
      const source = RemoteSource(stream: true);
      expect(source.stream, isTrue);
    });

    test('stream: false means blocking (waits for EOSE)', () {
      const source = RemoteSource(stream: false);
      expect(source.stream, isFalse);
    });

    test('LocalAndRemoteSource inherits stream behavior', () {
      const streamingSource = LocalAndRemoteSource();
      const blockingSource = LocalAndRemoteSource(stream: false);

      expect(streamingSource.stream, isTrue);
      expect(blockingSource.stream, isFalse);
    });

    test('cachedFor forces stream to false', () {
      const source = LocalAndRemoteSource(
        stream: true,
        cachedFor: Duration(minutes: 5),
      );
      // Even though stream: true was passed, cachedFor overrides it
      expect(source.stream, isFalse);
    });
  });
}

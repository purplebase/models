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
        group: 'social',
        stream: true,
        background: false,
      );
      const source2 = RemoteSource(
        group: 'social',
        stream: true,
        background: false,
      );
      expect(source1, equals(source2));
      expect(source1.hashCode, equals(source2.hashCode));
    });

    test('RemoteSource instances with different properties are not equal', () {
      const source1 = RemoteSource(stream: true, background: false);
      const source2 = RemoteSource(stream: true, background: true);
      expect(source1, isNot(equals(source2)));
    });

    test('LocalAndRemoteSource instances with same properties are equal', () {
      const source1 = LocalAndRemoteSource(
        group: 'social',
        stream: true,
        background: true,
      );
      const source2 = LocalAndRemoteSource(
        group: 'social',
        stream: true,
        background: true,
      );
      expect(source1, equals(source2));
      expect(source1.hashCode, equals(source2.hashCode));
    });

    test(
      'RemoteSource and LocalAndRemoteSource with same properties are not equal',
      () {
        const source1 = RemoteSource(
          group: 'social',
          stream: true,
          background: true,
        );
        const source2 = LocalAndRemoteSource(
          group: 'social',
          stream: true,
          background: true,
        );
        // Different types, so should not be equal
        expect(source1, isNot(equals(source2)));
      },
    );

    test('RemoteSource with different relayUrls are not equal', () {
      const source1 = RemoteSource(relayUrls: {'wss://relay1.com'});
      const source2 = RemoteSource(relayUrls: {'wss://relay2.com'});
      expect(source1, isNot(equals(source2)));
    });
  });

  group('Source copyWith', () {
    test('RemoteSource copyWith creates equal instance when no changes', () {
      const original = RemoteSource(
        group: 'social',
        stream: true,
        background: false,
      );
      final copied = original.copyWith();
      expect(copied, equals(original));
      expect(copied.group, equals('social'));
      expect(copied.stream, equals(true));
      expect(copied.background, equals(false));
    });

    test('RemoteSource copyWith updates single property', () {
      const original = RemoteSource(
        group: 'social',
        stream: true,
        background: false,
      );
      final modified = original.copyWith(background: true);

      expect(modified.group, equals('social'));
      expect(modified.stream, equals(true));
      expect(modified.background, equals(true));
      expect(modified, isNot(equals(original)));
    });

    test('RemoteSource copyWith updates multiple properties', () {
      const original = RemoteSource(
        group: 'social',
        stream: true,
        background: false,
      );
      final modified = original.copyWith(group: 'apps', stream: false);

      expect(modified.group, equals('apps'));
      expect(modified.stream, equals(false));
      expect(modified.background, equals(false)); // unchanged
    });

    test('RemoteSource copyWith updates relayUrls', () {
      const original = RemoteSource(relayUrls: {'wss://relay1.com'});
      final modified = original.copyWith(
        relayUrls: {'wss://relay1.com', 'wss://relay2.com'},
      );

      expect(
        modified.relayUrls,
        equals({'wss://relay1.com', 'wss://relay2.com'}),
      );
      expect(modified, isNot(equals(original)));
    });

    test('LocalAndRemoteSource copyWith preserves type', () {
      const original = LocalAndRemoteSource(
        group: 'social',
        stream: true,
        background: false,
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
          group: 'social',
          stream: true,
          background: false,
        );
        final modified = original.copyWith(background: true);

        expect(modified, isA<LocalAndRemoteSource>());
        expect(modified.background, equals(true));
        expect(modified.group, equals('social'));
        expect(modified.stream, equals(true));
      },
    );

    test('copyWith chain produces expected result', () {
      const original = RemoteSource();
      final result = original
          .copyWith(group: 'social')
          .copyWith(stream: false)
          .copyWith(background: true);

      expect(result.group, equals('social'));
      expect(result.stream, equals(false));
      expect(result.background, equals(true));
    });
  });

  group('Source type differentiation', () {
    test(
      'different Source types are not equal even with same underlying data',
      () {
        const remote = RemoteSource(stream: true, background: true);
        const localAndRemote = LocalAndRemoteSource(
          stream: true,
          background: true,
        );
        const local = LocalSource();

        expect(remote, isNot(equals(localAndRemote)));
        expect(remote, isNot(equals(local)));
        expect(localAndRemote, isNot(equals(local)));
      },
    );
  });
}

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('NwcConnection', () {
    test('creates connection with required properties', () {
      final connection = NwcConnection(
        walletPubkey: 'a' * 64,
        secret: 'b' * 64,
        relay: 'wss://relay.example.com',
        createdAt: DateTime.now(),
      );

      expect(connection.walletPubkey, 'a' * 64);
      expect(connection.secret, 'b' * 64);
      expect(connection.relay, 'wss://relay.example.com');
      expect(connection.lud16, isNull);
      expect(connection.limits, isNull);
      expect(connection.isExpired, isFalse);
    });

    test('creates connection with optional properties', () {
      final expiresAt = DateTime.now().add(Duration(hours: 1));
      final limits = NwcConnectionLimits(
        maxAmount: 10000,
        budgetRenewal: NwcBudgetRenewal.daily,
        allowedMethods: {'pay_invoice', 'get_balance'},
      );

      final connection = NwcConnection(
        walletPubkey: 'a' * 64,
        secret: 'b' * 64,
        relay: 'wss://relay.example.com',
        lud16: 'test@example.com',
        limits: limits,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
      );

      expect(connection.lud16, 'test@example.com');
      expect(connection.limits, limits);
      expect(connection.expiresAt, expiresAt);
      expect(connection.isExpired, isFalse);
    });

    test('detects expired connections', () {
      final connection = NwcConnection(
        walletPubkey: 'a' * 64,
        secret: 'b' * 64,
        relay: 'wss://relay.example.com',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().subtract(Duration(hours: 1)),
      );

      expect(connection.isExpired, isTrue);
    });

    test('derives client pubkey from secret', () {
      final connection = NwcConnection(
        walletPubkey: 'a' * 64,
        secret: 'b' * 64,
        relay: 'wss://relay.example.com',
        createdAt: DateTime.now(),
      );

      expect(connection.clientPubkey, isA<String>());
      expect(connection.clientPubkey.length, 64);
    });

    test('serializes to and from map', () {
      final limits = NwcConnectionLimits(
        maxAmount: 5000,
        budgetRenewal: NwcBudgetRenewal.weekly,
        allowedMethods: {'pay_invoice'},
      );

      final original = NwcConnection(
        walletPubkey: 'a' * 64,
        secret: 'b' * 64,
        relay: 'wss://relay.example.com',
        lud16: 'test@example.com',
        limits: limits,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(Duration(days: 30)),
      );

      final map = original.toMap();
      final restored = NwcConnection.fromMap(map);

      expect(restored.walletPubkey, original.walletPubkey);
      expect(restored.secret, original.secret);
      expect(restored.relay, original.relay);
      expect(restored.lud16, original.lud16);
      expect(restored.limits?.maxAmount, original.limits?.maxAmount);
      expect(restored.limits?.budgetRenewal, original.limits?.budgetRenewal);
      expect(restored.limits?.allowedMethods, original.limits?.allowedMethods);
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        original.createdAt.millisecondsSinceEpoch,
      );
      expect(
        restored.expiresAt?.millisecondsSinceEpoch,
        original.expiresAt?.millisecondsSinceEpoch,
      );
    });
  });

  group('NwcConnectionLimits', () {
    test('creates with default values', () {
      final limits = NwcConnectionLimits();

      expect(limits.maxAmount, isNull);
      expect(limits.budgetRenewal, NwcBudgetRenewal.never);
      expect(limits.allowedMethods, {'pay_invoice'});
    });

    test('serializes to and from map', () {
      final original = NwcConnectionLimits(
        maxAmount: 10000,
        budgetRenewal: NwcBudgetRenewal.monthly,
        allowedMethods: {'pay_invoice', 'get_balance', 'make_invoice'},
      );

      final map = original.toMap();
      final restored = NwcConnectionLimits.fromMap(map);

      expect(restored.maxAmount, original.maxAmount);
      expect(restored.budgetRenewal, original.budgetRenewal);
      expect(restored.allowedMethods, original.allowedMethods);
    });
  });

  group('NwcUriParser', () {
    test('parses valid NWC URI', () {
      const uri =
          'nostr+walletconnect://b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4?relay=wss%3A%2F%2Frelay.damus.io&secret=71a8c14c1407c113601079c4302dab36460f0ccd0ad506f1f2dc73b5100e4f3c';

      final connection = NwcUriParser.parse(uri);

      expect(
        connection.walletPubkey,
        'b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4',
      );
      expect(
        connection.secret,
        '71a8c14c1407c113601079c4302dab36460f0ccd0ad506f1f2dc73b5100e4f3c',
      );
      expect(connection.relay, 'wss://relay.damus.io');
      expect(connection.lud16, isNull);
    });

    test('parses NWC URI with lud16', () {
      const uri =
          'nostr+walletconnect://b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4?relay=wss%3A%2F%2Frelay.damus.io&secret=71a8c14c1407c113601079c4302dab36460f0ccd0ad506f1f2dc73b5100e4f3c&lud16=test%40example.com';

      final connection = NwcUriParser.parse(uri);

      expect(
        connection.walletPubkey,
        'b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4',
      );
      expect(
        connection.secret,
        '71a8c14c1407c113601079c4302dab36460f0ccd0ad506f1f2dc73b5100e4f3c',
      );
      expect(connection.relay, 'wss://relay.damus.io');
      expect(connection.lud16, 'test@example.com');
    });

    test('throws on invalid protocol', () {
      const uri = 'invalid://test';

      expect(
        () => NwcUriParser.parse(uri),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('must start with nostr+walletconnect://'),
          ),
        ),
      );
    });

    test('throws on missing query parameters', () {
      const uri =
          'nostr+walletconnect://b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4';

      expect(
        () => NwcUriParser.parse(uri),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('missing query parameters'),
          ),
        ),
      );
    });

    test('throws on invalid wallet pubkey length', () {
      const uri =
          'nostr+walletconnect://invalid?relay=wss://relay.damus.io&secret=71a8c14c1407c113601079c4302dab36460f0ccd0ad506f1f2dc73b5100e4f3c';

      expect(
        () => NwcUriParser.parse(uri),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('wallet pubkey must be 64 hex characters'),
          ),
        ),
      );
    });

    test('throws on missing relay parameter', () {
      const uri =
          'nostr+walletconnect://b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4?secret=71a8c14c1407c113601079c4302dab36460f0ccd0ad506f1f2dc73b5100e4f3c';

      expect(
        () => NwcUriParser.parse(uri),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('missing required relay parameter'),
          ),
        ),
      );
    });

    test('throws on missing secret parameter', () {
      const uri =
          'nostr+walletconnect://b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4?relay=wss://relay.damus.io';

      expect(
        () => NwcUriParser.parse(uri),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('missing required secret parameter'),
          ),
        ),
      );
    });

    test('throws on invalid secret length', () {
      const uri =
          'nostr+walletconnect://b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4?relay=wss://relay.damus.io&secret=invalid';

      expect(
        () => NwcUriParser.parse(uri),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('secret must be 64 hex characters'),
          ),
        ),
      );
    });

    test('generates URI from connection', () {
      final connection = NwcConnection(
        walletPubkey:
            'b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4',
        secret:
            '71a8c14c1407c113601079c4302dab36460f0ccd0ad506f1f2dc73b5100e4f3c',
        relay: 'wss://relay.damus.io',
        lud16: 'test@example.com',
        createdAt: DateTime.now(),
      );

      final uri = NwcUriParser.generate(connection);

      expect(uri, contains('nostr+walletconnect://'));
      expect(uri, contains(connection.walletPubkey));
      expect(uri, contains('relay=wss%3A%2F%2Frelay.damus.io'));
      expect(uri, contains('secret=${connection.secret}'));
      expect(uri, contains('lud16=test%40example.com'));
    });

    test('roundtrip parse and generate', () {
      const originalUri =
          'nostr+walletconnect://b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4?relay=wss%3A%2F%2Frelay.damus.io&secret=71a8c14c1407c113601079c4302dab36460f0ccd0ad506f1f2dc73b5100e4f3c&lud16=test%40example.com';

      final connection = NwcUriParser.parse(originalUri);
      final generatedUri = NwcUriParser.generate(connection);
      final reparsedConnection = NwcUriParser.parse(generatedUri);

      expect(reparsedConnection.walletPubkey, connection.walletPubkey);
      expect(reparsedConnection.secret, connection.secret);
      expect(reparsedConnection.relay, connection.relay);
      expect(reparsedConnection.lud16, connection.lud16);
    });
  });

  group('NwcBudgetRenewal', () {
    test('has all expected values', () {
      expect(NwcBudgetRenewal.values, hasLength(5));
      expect(NwcBudgetRenewal.values, contains(NwcBudgetRenewal.never));
      expect(NwcBudgetRenewal.values, contains(NwcBudgetRenewal.daily));
      expect(NwcBudgetRenewal.values, contains(NwcBudgetRenewal.weekly));
      expect(NwcBudgetRenewal.values, contains(NwcBudgetRenewal.monthly));
      expect(NwcBudgetRenewal.values, contains(NwcBudgetRenewal.yearly));
    });
  });
}

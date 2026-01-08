import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;
  late Signer signer;

  setUp(() async {
    container = await createTestContainer(
      config: StorageConfiguration(keepSignatures: false),
    );
    ref = container.read(refProvider);

    // Create and sign in a test signer
    final privateKey = Utils.generateRandomHex64();
    signer = Bip340PrivateKeySigner(privateKey, ref);
    await signer.signIn();

  });

  tearDown(() async {
    await container.read(storageNotifierProvider.notifier).clear();
    container.dispose();
  });

  group('NWC Commands', () {
    test('PayInvoiceCommand creates correct structure', () {
      const invoice = 'lnbc1000n1pjqwdqcpp5...';
      final command = PayInvoiceCommand(invoice: invoice);

      expect(command.method, equals(NwcInfo.payInvoice));
      expect(command.params['invoice'], equals(invoice));

      final request = PartialNwcRequest(
        walletPubkey: franzapPubkey,
        method: command.method,
        params: command.params,
        expiration: DateTime.now().add(Duration(minutes: 5)),
      );

      expect(request.event.kind, equals(23194));
      expect(request.event.getFirstTagValue('p'), equals(franzapPubkey));
      expect(request.event.content, isNotEmpty);
    });
  });

  group('ZapRequest.pay()', () {
    test('throws when connection URI is invalid', () async {
      final zapRequest = PartialZapRequest();
      zapRequest.amount = 1000;
      zapRequest.linkProfileByPubkey(franzapPubkey);

      final signedZapRequest = await zapRequest.signWith(signer);

      await expectLater(
        () => signedZapRequest.pay(connectionUri: 'invalid-uri-format'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

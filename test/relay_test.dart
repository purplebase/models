import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  test('relay request should notify with events', () async {
    final container = ProviderContainer();
    final relay = container.read(relayNotifierProvider);

    final req = RelayRequest(
        kinds: {1}, authors: {'a', 'b'}, limit: 2, bufferUntilEose: true);
    relay.send(req);

    final tester = RelayNotifierTester(relay);
    await tester.expect(isA<RelayData>()
        .having((s) => s.subscriptionId, 'sub', equals(req.subscriptionId))
        .having((s) => s.models, 'models',
            hasLength(4))); // limit * number of authors
    tester.dispose();
  });
}

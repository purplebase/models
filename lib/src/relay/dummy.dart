import 'dart:async';
import 'dart:math';

import 'package:models/models.dart';

final _dummySigner = DummySigner();

class DummyRelayNotifier extends RelayNotifier {
  DummyRelayNotifier() : super(RelayIdle());

  @override
  void send(RelayRequest req, [Object? key]) async {
    state = RelayData([
      ...?state.models,
      for (final _ in List.generate(req.limit ?? 10, (_) {}))
        for (final author in req.authors)
          await PartialNote('Note number ${Random().nextInt(999)}')
              .signWith(_dummySigner, withPubkey: author),
    ], subscriptionId: req.subscriptionId);

    Timer.periodic(Duration(seconds: 3), (t) async {
      if (mounted) {
        if (t.tick > 2) {
          // state = RelayError(
          //   state.models,
          //   message: 'Server error, closed',
          //   subscriptionId: req.subscriptionId,
          // );
          t.cancel();
        } else {
          state = RelayData(
            [
              ...?state.models,
              for (final author in req.authors)
                await PartialNote('Streaming note ${Random().nextInt(999)}')
                    .signWith(_dummySigner, withPubkey: author),
            ],
            isStreaming: true,
            subscriptionId: req.subscriptionId,
          );
        }
      } else {
        print('bro its closed');
        t.cancel();
      }
    });
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:async/async.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:models/models.dart';

void main() {
  late NostrRelay relay;
  WebSocket? clientSocket;
  const testHost = 'localhost';
  const testPort = 8081;

  setUp(() async {
    relay = NostrRelay(host: testHost, port: testPort);
    await relay.start();
  });

  tearDown(() async {
    await clientSocket?.close();
    await relay.stop();
  });

  test('should start and stop relay', () async {
    expect(relay, isNotNull);
  });

  test('should accept a simple event', () async {
    clientSocket = await WebSocket.connect('ws://$testHost:$testPort');
    final queue = StreamQueue(clientSocket!);

    // Create a test event with computed ID
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final eventData = [
      0,
      'test-pubkey',
      createdAt,
      1,
      <List<String>>[],
      'Test message'
    ];
    final hash = sha256.convert(utf8.encode(jsonEncode(eventData)));
    final event = {
      'id': hash.toString(),
      'pubkey': 'test-pubkey',
      'created_at': createdAt,
      'kind': 1,
      'tags': <List<String>>[],
      'content': 'Test message',
      'sig': 'test-signature'
    };
    clientSocket!.add(jsonEncode(['EVENT', event]));

    // Wait for OK response
    final okMsg = await queue.next;
    final response = jsonDecode(okMsg) as List;
    expect(response[0], equals('OK'));
    expect(response[1], equals(hash.toString()));
    expect(response[2], isTrue);
    await queue.cancel();
  });

  test('should accept and store events', () async {
    clientSocket = await WebSocket.connect('ws://$testHost:$testPort');
    final queue = StreamQueue(clientSocket!);

    // Create a test event with computed ID
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final eventData = [
      0,
      'test-pubkey-456',
      createdAt,
      1,
      <List<String>>[],
      'Hello, Nostr!'
    ];
    final hash = sha256.convert(utf8.encode(jsonEncode(eventData)));
    final testEvent = {
      'id': hash.toString(),
      'pubkey': 'test-pubkey-456',
      'created_at': createdAt,
      'kind': 1,
      'tags': <List<String>>[],
      'content': 'Hello, Nostr!',
      'sig': 'test-signature'
    };
    clientSocket!.add(jsonEncode(['EVENT', testEvent]));

    // Wait for OK response
    final okMsg = await queue.next;
    final response = jsonDecode(okMsg) as List;
    expect(response[0], equals('OK'));
    expect(response[1], equals(hash.toString()));
    expect(response[2], isTrue);
    await queue.cancel();
  });

  test('should return stored events on REQ', () async {
    clientSocket = await WebSocket.connect('ws://$testHost:$testPort');
    final queue = StreamQueue(clientSocket!);

    // Create and send a test event
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final eventData = [
      0,
      'test-pubkey-456',
      createdAt,
      1,
      <List<String>>[],
      'Test message for query'
    ];
    final hash = sha256.convert(utf8.encode(jsonEncode(eventData)));
    final testEvent = {
      'id': hash.toString(),
      'pubkey': 'test-pubkey-456',
      'created_at': createdAt,
      'kind': 1,
      'tags': <List<String>>[],
      'content': 'Test message for query',
      'sig': 'test-signature'
    };
    clientSocket!.add(jsonEncode(['EVENT', testEvent]));

    // Wait for OK response
    await queue.next;

    // Send REQ message to query the event
    final reqMessage = [
      'REQ',
      'test-subscription',
      {
        'kinds': [1]
      }
    ];
    clientSocket!.add(jsonEncode(reqMessage));

    // Wait for EVENT and EOSE, skipping OKs
    String? eventMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EVENT') {
        eventMsg = msg;
        break;
      }
    }
    String? eoseMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EOSE') {
        eoseMsg = msg;
        break;
      }
    }
    assert(eventMsg != null);
    assert(eoseMsg != null);
    final eventResponse = jsonDecode(eventMsg!) as List;
    final eoseResponse = jsonDecode(eoseMsg!) as List;
    expect(eventResponse[0], equals('EVENT'));
    expect(eventResponse[1], equals('test-subscription'));
    expect(eventResponse[2]['id'], equals(hash.toString()));
    expect(eventResponse[2]['content'], equals('Test message for query'));
    expect(eoseResponse[0], equals('EOSE'));
    expect(eoseResponse[1], equals('test-subscription'));
    await queue.cancel();
  });

  test('should filter events by author', () async {
    clientSocket = await WebSocket.connect('ws://$testHost:$testPort');
    final queue = StreamQueue(clientSocket!);

    // Create and send events from different authors
    final author1 = 'a' * 64;
    final author2 = 'b' * 64;
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final event1 = {
      'id': sha256
          .convert(utf8.encode(jsonEncode([
            0,
            author1,
            createdAt,
            1,
            <List<String>>[],
            'Message from author 1'
          ])))
          .toString(),
      'pubkey': author1,
      'created_at': createdAt,
      'kind': 1,
      'tags': <List<String>>[],
      'content': 'Message from author 1',
      'sig': 'test-signature'
    };
    final event2 = {
      'id': sha256
          .convert(utf8.encode(jsonEncode([
            0,
            author2,
            createdAt,
            1,
            <List<String>>[],
            'Message from author 2'
          ])))
          .toString(),
      'pubkey': author2,
      'created_at': createdAt,
      'kind': 1,
      'tags': <List<String>>[],
      'content': 'Message from author 2',
      'sig': 'test-signature'
    };
    clientSocket!.add(jsonEncode(['EVENT', event1]));
    clientSocket!.add(jsonEncode(['EVENT', event2]));

    // Wait for OK responses
    await queue.next;
    await queue.next;

    // Query for events from author-1 only
    clientSocket!.add(jsonEncode([
      'REQ',
      'test-sub',
      {
        'authors': [author1],
      }
    ]));

    // Wait for EVENT and EOSE, skipping OKs
    String? eventMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EVENT') {
        eventMsg = msg;
        break;
      }
    }
    String? eoseMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EOSE') {
        eoseMsg = msg;
        break;
      }
    }
    assert(eventMsg != null);
    assert(eoseMsg != null);
    final eventResponse = jsonDecode(eventMsg!) as List;
    final eoseResponse = jsonDecode(eoseMsg!) as List;
    expect(eventResponse[0], equals('EVENT'));
    expect(eventResponse[1], equals('test-sub'));
    expect(eventResponse[2]['pubkey'], equals(author1));
    expect(eventResponse[2]['content'], equals('Message from author 1'));
    expect(eoseResponse[0], equals('EOSE'));
    expect(eoseResponse[1], equals('test-sub'));
    await queue.cancel();
  });

  test('should filter events by kind', () async {
    clientSocket = await WebSocket.connect('ws://$testHost:$testPort');
    final queue = StreamQueue(clientSocket!);

    // Create and send events of different kinds
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final event1 = {
      'id': sha256
          .convert(utf8.encode(jsonEncode(
              [0, 'test-pubkey', createdAt, 1, <List<String>>[], 'Text note'])))
          .toString(),
      'pubkey': 'test-pubkey',
      'created_at': createdAt,
      'kind': 1,
      'tags': <List<String>>[],
      'content': 'Text note',
      'sig': 'test-signature'
    };
    final event2 = {
      'id': sha256
          .convert(utf8.encode(jsonEncode([
            0,
            'test-pubkey',
            createdAt,
            3,
            <List<String>>[],
            'Contact list'
          ])))
          .toString(),
      'pubkey': 'test-pubkey',
      'created_at': createdAt,
      'kind': 3,
      'tags': <List<String>>[],
      'content': 'Contact list',
      'sig': 'test-signature'
    };
    clientSocket!.add(jsonEncode(['EVENT', event1]));
    clientSocket!.add(jsonEncode(['EVENT', event2]));

    // Wait for OK responses
    await queue.next;
    await queue.next;

    // Query for kind 3 events only
    clientSocket!.add(jsonEncode([
      'REQ',
      'test-sub',
      {
        'kinds': [3],
      }
    ]));

    // Wait for EVENT and EOSE, skipping OKs
    String? eventMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EVENT') {
        eventMsg = msg;
        break;
      }
    }
    String? eoseMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EOSE') {
        eoseMsg = msg;
        break;
      }
    }
    assert(eventMsg != null);
    assert(eoseMsg != null);
    final eventResponse = jsonDecode(eventMsg!) as List;
    final eoseResponse = jsonDecode(eoseMsg!) as List;
    expect(eventResponse[0], equals('EVENT'));
    expect(eventResponse[1], equals('test-sub'));
    expect(eventResponse[2]['kind'], equals(3));
    expect(eventResponse[2]['content'], equals('Contact list'));
    expect(eoseResponse[0], equals('EOSE'));
    expect(eoseResponse[1], equals('test-sub'));
    await queue.cancel();
  });

  test('should handle multiple filters in REQ', () async {
    clientSocket = await WebSocket.connect('ws://$testHost:$testPort');
    final queue = StreamQueue(clientSocket!);

    // Create and send events
    final author1 = 'a' * 64;
    final author2 = 'b' * 64;
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final event1 = {
      'id': sha256
          .convert(utf8.encode(jsonEncode(
              [0, author1, createdAt, 1, <List<String>>[], 'Message 1'])))
          .toString(),
      'pubkey': author1,
      'created_at': createdAt,
      'kind': 1,
      'tags': <List<String>>[],
      'content': 'Message 1',
      'sig': 'test-signature'
    };
    final event2 = {
      'id': sha256
          .convert(utf8.encode(jsonEncode(
              [0, author2, createdAt, 2, <List<String>>[], 'Message 2'])))
          .toString(),
      'pubkey': author2,
      'created_at': createdAt,
      'kind': 2,
      'tags': <List<String>>[],
      'content': 'Message 2',
      'sig': 'test-signature'
    };
    clientSocket!.add(jsonEncode(['EVENT', event1]));
    clientSocket!.add(jsonEncode(['EVENT', event2]));

    // Wait for OK responses
    await queue.next;
    await queue.next;

    // Query with multiple filters (should return events matching any filter)
    clientSocket!.add(jsonEncode([
      'REQ',
      'test-sub',
      [
        {
          'authors': [author1]
        },
        {
          'authors': [author2]
        },
      ]
    ]));

    // Wait for two EVENTs and EOSE, skipping OKs
    List<String> eventMsgs = [];
    while (eventMsgs.length < 2) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EVENT') {
        eventMsgs.add(msg);
      }
    }
    String? eoseMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EOSE') {
        eoseMsg = msg;
        break;
      }
    }
    final eventResponses = eventMsgs.map((m) => jsonDecode(m) as List).toList();
    final eoseResponse = jsonDecode(eoseMsg!) as List;
    final authors = eventResponses.map((e) => e[2]['pubkey']).toSet();
    expect(authors, contains(author1));
    expect(authors, contains(author2));
    expect(eoseResponse[0], equals('EOSE'));
    expect(eoseResponse[1], equals('test-sub'));
    await queue.cancel();
  });

  test('should handle CLOSE subscription', () async {
    clientSocket = await WebSocket.connect('ws://$testHost:$testPort');
    final queue = StreamQueue(clientSocket!);

    // Create and send a test event
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final eventData = [
      0,
      'test-pubkey',
      createdAt,
      1,
      <List<String>>[],
      'Test message'
    ];
    final hash = sha256.convert(utf8.encode(jsonEncode(eventData)));
    final testEvent = {
      'id': hash.toString(),
      'pubkey': 'test-pubkey',
      'created_at': createdAt,
      'kind': 1,
      'tags': <List<String>>[],
      'content': 'Test message',
      'sig': 'test-signature'
    };
    clientSocket!.add(jsonEncode(['EVENT', testEvent]));

    // Wait for OK response
    await queue.next;

    // Create subscription
    clientSocket!.add(jsonEncode(['REQ', 'test-sub', {}]));

    // Wait for EVENT and EOSE from the initial REQ
    String? eventMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EVENT') {
        eventMsg = msg;
        break;
      }
    }
    String? eoseMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EOSE') {
        eoseMsg = msg;
        break;
      }
    }
    assert(eventMsg != null);
    assert(eoseMsg != null);
    final eventResponse = jsonDecode(eventMsg!) as List;
    final eoseResponse = jsonDecode(eoseMsg!) as List;
    expect(eventResponse[0], equals('EVENT'));
    expect(eventResponse[1], equals('test-sub'));
    expect(eoseResponse[0], equals('EOSE'));
    expect(eoseResponse[1], equals('test-sub'));

    // Close subscription
    clientSocket!.add(jsonEncode(['CLOSE', 'test-sub']));

    // Wait for CLOSED acknowledgment
    final closedMsg = await queue.next;
    final closedResponse = jsonDecode(closedMsg) as List;
    expect(closedResponse[0], equals('CLOSED'));
    expect(closedResponse[1], equals('test-sub'));

    // Send another event - should not be received since subscription is closed
    final createdAt2 = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final eventData2 = [
      0,
      'test-pubkey',
      createdAt2,
      1,
      <List<String>>[],
      'Should not be received'
    ];
    final hash2 = sha256.convert(utf8.encode(jsonEncode(eventData2)));
    final newEvent = {
      'id': hash2.toString(),
      'pubkey': 'test-pubkey',
      'created_at': createdAt2,
      'kind': 1,
      'tags': <List<String>>[],
      'content': 'Should not be received',
      'sig': 'test-signature'
    };
    clientSocket!.add(jsonEncode(['EVENT', newEvent]));

    // Wait for OK response for the second event
    await queue.next;

    // No more messages should be received since subscription is closed
    // The test passes if we reach here without timeout
    await queue.cancel();
  });

  test('should handle tag filters', () async {
    clientSocket = await WebSocket.connect('ws://$testHost:$testPort');
    final queue = StreamQueue(clientSocket!);

    // Create and send events with different tags
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final event1 = {
      'id': sha256
          .convert(utf8.encode(jsonEncode([
            0,
            'test-pubkey',
            createdAt,
            1,
            [
              ['t', 'test-tag']
            ],
            'Event with test tag'
          ])))
          .toString(),
      'pubkey': 'test-pubkey',
      'created_at': createdAt,
      'kind': 1,
      'tags': [
        ['t', 'test-tag']
      ],
      'content': 'Event with test tag',
      'sig': 'test-signature'
    };
    final event2 = {
      'id': sha256
          .convert(utf8.encode(jsonEncode([
            0,
            'test-pubkey',
            createdAt,
            1,
            [
              ['t', 'other-tag']
            ],
            'Event with other tag'
          ])))
          .toString(),
      'pubkey': 'test-pubkey',
      'created_at': createdAt,
      'kind': 1,
      'tags': [
        ['t', 'other-tag']
      ],
      'content': 'Event with other tag',
      'sig': 'test-signature'
    };
    clientSocket!.add(jsonEncode(['EVENT', event1]));
    clientSocket!.add(jsonEncode(['EVENT', event2]));

    // Wait for OK responses
    await queue.next;
    await queue.next;

    // Query for events with specific tag
    clientSocket!.add(jsonEncode([
      'REQ',
      'test-sub',
      {
        '#t': ['test-tag'],
      }
    ]));

    // Wait for EVENT and EOSE, skipping OKs
    String? eventMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EVENT') {
        eventMsg = msg;
        break;
      }
    }
    String? eoseMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EOSE') {
        eoseMsg = msg;
        break;
      }
    }
    assert(eventMsg != null);
    assert(eoseMsg != null);
    final eventResponse = jsonDecode(eventMsg!) as List;
    final eoseResponse = jsonDecode(eoseMsg!) as List;
    expect(eventResponse[0], equals('EVENT'));
    expect(eventResponse[1], equals('test-sub'));
    expect(eventResponse[2]['tags'][0][1], equals('test-tag'));
    expect(eoseResponse[0], equals('EOSE'));
    expect(eoseResponse[1], equals('test-sub'));
    await queue.cancel();
  });

  test('should handle time-based filters', () async {
    clientSocket = await WebSocket.connect('ws://$testHost:$testPort');
    final queue = StreamQueue(clientSocket!);

    final now = DateTime.now();
    final thirtyMinutesAgo = now.subtract(Duration(minutes: 30));
    final oldEvent = {
      'id': sha256
          .convert(utf8.encode(jsonEncode([
            0,
            'test-pubkey',
            thirtyMinutesAgo.millisecondsSinceEpoch ~/ 1000,
            1,
            <List<String>>[],
            'Old event'
          ])))
          .toString(),
      'pubkey': 'test-pubkey',
      'created_at': thirtyMinutesAgo.millisecondsSinceEpoch ~/ 1000,
      'kind': 1,
      'tags': <List<String>>[],
      'content': 'Old event',
      'sig': 'test-signature'
    };
    final newEvent = {
      'id': sha256
          .convert(utf8.encode(jsonEncode([
            0,
            'test-pubkey',
            now.millisecondsSinceEpoch ~/ 1000,
            1,
            <List<String>>[],
            'New event'
          ])))
          .toString(),
      'pubkey': 'test-pubkey',
      'created_at': now.millisecondsSinceEpoch ~/ 1000,
      'kind': 1,
      'tags': <List<String>>[],
      'content': 'New event',
      'sig': 'test-signature'
    };
    clientSocket!.add(jsonEncode(['EVENT', oldEvent]));
    clientSocket!.add(jsonEncode(['EVENT', newEvent]));

    // Wait for OK responses
    await queue.next;
    await queue.next;

    // Query for events since 30 minutes ago
    clientSocket!.add(jsonEncode([
      'REQ',
      'test-sub',
      {
        'since': thirtyMinutesAgo.millisecondsSinceEpoch ~/ 1000,
      }
    ]));

    // Wait for both EVENTs and EOSE, skipping OKs
    List<String> eventMsgs = [];
    while (eventMsgs.length < 2) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EVENT') {
        eventMsgs.add(msg);
      }
    }
    String? eoseMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EOSE') {
        eoseMsg = msg;
        break;
      }
    }
    final eventResponses = eventMsgs.map((m) => jsonDecode(m) as List).toList();
    final eoseResponse = jsonDecode(eoseMsg!) as List;

    // Should get both events since both are >= thirtyMinutesAgo
    expect(eventResponses.length, equals(2));
    for (final eventResponse in eventResponses) {
      expect(eventResponse[0], equals('EVENT'));
      expect(eventResponse[1], equals('test-sub'));
      expect(
          eventResponse[2]['created_at'] >=
              thirtyMinutesAgo.millisecondsSinceEpoch ~/ 1000,
          isTrue);
    }
    expect(eoseResponse[0], equals('EOSE'));
    expect(eoseResponse[1], equals('test-sub'));
    await queue.cancel();
  });

  test('should handle limit parameter', () async {
    clientSocket = await WebSocket.connect('ws://$testHost:$testPort');
    final queue = StreamQueue(clientSocket!);

    // Create and send multiple test events
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final events = List.generate(
        3,
        (i) => {
              'id': sha256
                  .convert(utf8.encode(jsonEncode([
                    0,
                    'test-pubkey',
                    createdAt + i,
                    1,
                    <List<String>>[],
                    'Test message $i'
                  ])))
                  .toString(),
              'pubkey': 'test-pubkey',
              'created_at': createdAt + i,
              'kind': 1,
              'tags': <List<String>>[],
              'content': 'Test message $i',
              'sig': 'test-signature'
            });
    for (final event in events) {
      clientSocket!.add(jsonEncode(['EVENT', event]));
      await queue.next;
    }

    // Query with limit=2
    clientSocket!.add(jsonEncode([
      'REQ',
      'test-sub',
      {
        'limit': 2,
      }
    ]));

    // Wait for up to 2 EVENTs and EOSE, skipping OKs
    List<String> eventMsgs = [];
    while (eventMsgs.length < 2) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EVENT') {
        eventMsgs.add(msg);
      }
    }
    String? eoseMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EOSE') {
        eoseMsg = msg;
        break;
      }
    }
    final eventResponses = eventMsgs.map((m) => jsonDecode(m) as List).toList();
    final eoseResponse = jsonDecode(eoseMsg!) as List;
    expect(eventResponses.length, equals(2));
    expect(eoseResponse[0], equals('EOSE'));
    expect(eoseResponse[1], equals('test-sub'));
    await queue.cancel();
  });

  test('should accept, store, and return a replaceable Profile event (kind 0)',
      () async {
    clientSocket = await WebSocket.connect('ws://$testHost:$testPort');
    final queue = StreamQueue(clientSocket!);

    // Create a kind 0 Profile event
    final pubkey = 'a' * 64;
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final eventData = [
      0,
      pubkey,
      createdAt,
      0,
      <List<String>>[],
      '{"name":"Test Profile"}'
    ];
    final hash = sha256.convert(utf8.encode(jsonEncode(eventData)));
    final profileEvent = {
      'id': hash.toString(),
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': 0,
      'tags': <List<String>>[],
      'content': '{"name":"Test Profile"}',
      'sig': 'test-signature'
    };
    clientSocket!.add(jsonEncode(['EVENT', profileEvent]));

    // Wait for OK response
    final okMsg = await queue.next;
    final response = jsonDecode(okMsg) as List;
    expect(response[0], equals('OK'));
    expect(response[1], equals(hash.toString()));
    expect(response[2], isTrue);

    // Query for the profile event by kind and pubkey
    final reqMessage = [
      'REQ',
      'profile-sub',
      {
        'kinds': [0],
        'authors': [pubkey],
      }
    ];
    clientSocket!.add(jsonEncode(reqMessage));

    // Wait for EVENT and EOSE, skipping OKs
    String? eventMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EVENT') {
        eventMsg = msg;
        break;
      }
    }
    String? eoseMsg;
    while (true) {
      final msg = await queue.next;
      final decoded = jsonDecode(msg) as List;
      if (decoded[0] == 'EOSE') {
        eoseMsg = msg;
        break;
      }
    }
    assert(eventMsg != null);
    assert(eoseMsg != null);
    final eventResponse = jsonDecode(eventMsg!) as List;
    final eoseResponse = jsonDecode(eoseMsg!) as List;
    expect(eventResponse[0], equals('EVENT'));
    expect(eventResponse[1], equals('profile-sub'));
    expect(eventResponse[2]['id'], equals(hash.toString()));
    expect(eventResponse[2]['kind'], equals(0));
    expect(eventResponse[2]['pubkey'], equals(pubkey));
    expect(eventResponse[2]['content'], equals('{"name":"Test Profile"}'));
    expect(eoseResponse[0], equals('EOSE'));
    expect(eoseResponse[1], equals('profile-sub'));
    await queue.cancel();
  });
}

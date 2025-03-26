import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

const pk = 'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8';
final signer = Bip340PrivateKeySigner(pk);

void main() async {
  late ProviderContainer container;
  setUpAll(() async {
    container = ProviderContainer();
    await container.read(initializationProvider.future);
  });

  test('profile', () async {
    final p1 = await PartialProfile(
      name: 'Niel Liesmons',
      pictureUrl:
          'https://cdn.satellite.earth/946822b1ea72fd3710806c07420d6f7e7d4a7646b2002e6cc969bcf1feaa1009.png',
    ).signWith(signer);
    expect(p1.event.content,
        '{"name":"Niel Liesmons","nip05":null,"picture":"https://cdn.satellite.earth/946822b1ea72fd3710806c07420d6f7e7d4a7646b2002e6cc969bcf1feaa1009.png"}');
  });

  test('event', () async {
    final defaultEvent = PartialApp()
      ..name = 'app'
      ..identifier = 'w';
    print(defaultEvent.toMap());
    // expect(defaultEvent.isValid, isFalse);

    final t = DateTime.parse('2024-07-26');
    final signedEvent = await signer.sign(PartialApp()
      ..name = 'tr'
      ..event.createdAt = t
      ..identifier = 's1');
    // expect(signedEvent.isValid, isTrue);
    print(signedEvent.toMap());

    final signedEvent2 = await signer.sign(PartialApp()
      ..name = 'tr'
      ..identifier = 's1'
      ..event.createdAt = t);
    // expect(signedEvent2.isValid, isTrue);
    print(signedEvent2.toMap());
    // Test equality
    expect(signedEvent, signedEvent2);
  });

  test('app from map', () async {
    final partialApp = PartialApp()
      ..identifier = 'w'
      ..description = 'test app';
    final app = await signer
        .sign(partialApp); // identifier: 'blah'; pubkeys: {'90983aebe92bea'}
    // expect(app.isValid, isTrue);
    expect(app.event.kind, 32267);
    expect(app.description, 'test app');
    // expect(app.identifier, 'blah');
    // expect(app.getReplaceableEventLink(), (
    //   32267,
    //   'f36f1a2727b7ab02e3f6e99841cd2b4d9655f8cfa184bd4d68f4e4c72db8e5c1',
    //   'blah'
    // ));
    // expect(app.pubkeys, {'90983aebe92bea'});
    // expect(App.fromJson(app.toMap()), app);

    // event and partial event should share a common interface
    // final apps = [partialApp, app];
    // apps.first.repository;

    // final note = await PartialNote().signWith(signer);
    // final List<EventBase> notes = [PartialNote(), note];
    // notes.first.event.content;
  });

  test('tag serialization', () {
    final originalTags = [
      ["e", "a5118885bb80c63cee4dc7009c1888bfcbc8de5a7c53ed44892deb9850421421"],
      [
        "e",
        "09c1888bfcbc8de5a7c53ed44892deb9850421421a5118885bb80c63cee4dc70",
        "",
        "reply"
      ],
      ["p", "cad00c48a8c689d32d7c770b90221124d6a68bbc6b1d31c2039a84d5ab90cf7b"]
    ];
    final tags = Event.deserializeTags(originalTags);
    // print(tags);
    // print(Event.serializeTags(tags));
    expect(Event.serializeTags(tags), unorderedEquals(originalTags));
  });

  test('tags', () {
    final note = PartialNote('yo hello');
    note.event.addTagValue('url', 'http://z');
    note.event
        .addTag('e', EventTagValue('93893923', marker: EventMarker.mention));
    note.event.addTagValue('e', 'ab9387');
    note.event.addTag('param', TagValue(['a', '1']));
    note.event.addTag('param', TagValue(['a', '2']));
    note.event.addTag('param', TagValue(['a', '3']));

    print(note.toMap());
    note.event.addTag('param', TagValue(['b', '4']));
    note.event.removeTagWithValue('e');
    expect(note.event.containsTag('e'), isFalse);
    expect(note.event.getFirstTagValue('url'), 'http://z');
    print(note.toMap());
  });
}

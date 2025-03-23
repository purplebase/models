import 'package:models/models.dart';
import 'package:test/test.dart';

const pk = 'deef3563ddbf74e62b2e8e5e44b25b8d63fb05e29a991f7e39cff56aa3ce82b8';
final signer = Bip340PrivateKeySigner(pk);

void main() async {
  test('profile', () async {
    final p1 = await PartialProfile(
      name: 'Niel Liesmons',
      pictureUrl:
          'https://cdn.satellite.earth/946822b1ea72fd3710806c07420d6f7e7d4a7646b2002e6cc969bcf1feaa1009.png',
    ).signWith(signer);
    print(p1);
    expect(p1.event.content, isNotNull);

    final p2 = await PartialProfile(
      name: 'Zapchat',
      pictureUrl:
          'https://cdn.satellite.earth/307b087499ae5444de1033e62ac98db7261482c1531e741afad44a0f8f9871ee.png',
    ).signWith(signer);
    print(p2);

    final p3 = await PartialProfile(
      name: 'Proof Of Reign',
      pictureUrl:
          'https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Fmedia.architecturaldigest.in%2Fwp-content%2Fuploads%2F2019%2F04%2FNorth-Rose-window-notre-dame-paris.jpg&f=1&nofb=1&ipt=b915d5a064b905567aa5fe9fbc8c38da207c4ba007316f5055e3e8cb1a009aa8&ipo=images',
    ).signWith(signer);
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
    expect(App.fromJson(app.toMap()), app);

    // event and partial event should share a common interface
    // final apps = [partialApp, app];
    // apps.first.repository;

    // final note = await PartialNote().signWith(signer);
    // final List<EventBase> notes = [PartialNote(), note];
    // notes.first.event.content;
  });

  test('tags', () {
    final note = PartialNote('yo hello')
      ..event.tags = [
        ['url', 'http://z'],
        ['e', '93893923', 'mention'],
        ['e', 'ab9387'],
        ['param', 'a', '1'],
        ['param', 'a', '2'],
        ['param', 'b', '3']
      ];
    print(note.toMap());
    note.event.addTag('param', {'b', '4'});
    note.event.removeTag('e');
    expect(note.event.containsTag('e'), isFalse);
    expect(note.event.getTag('url'), 'http://z');
    print(note.toMap());
  });
}

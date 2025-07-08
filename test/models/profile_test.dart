import 'dart:convert';

import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;
  late Ref ref;
  late DummyStorageNotifier storage;

  setUpAll(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    ref = container.read(refProvider);
    storage = container.read(storageNotifierProvider.notifier)
        as DummyStorageNotifier;
  });

  group('Profile & ContactList', () {
    test('profile & contact list', () async {
      final nielProfile = PartialProfile(
        name: 'Niel Liesmons',
        pictureUrl:
            'https://cdn.satellite.earth/946822b1ea72fd3710806c07420d6f7e7d4a7646b2002e6cc969bcf1feaa1009.png',
      ).dummySign(nielPubkey);

      expect(nielProfile.event.content,
          '{"name":"Niel Liesmons","picture":"https://cdn.satellite.earth/946822b1ea72fd3710806c07420d6f7e7d4a7646b2002e6cc969bcf1feaa1009.png"}');
      expect(nielProfile.event.shareableId,
          'nprofile1qqs2js6wu9j76qdjs6lvlsnhrmchqhf4xlg9rvu89zyf3nqq6hygt0sty4s8y');

      final franzapProfile = Profile.fromMap(jsonDecode(franzapJson), ref);
      final verbirichaProfile =
          Profile.fromMap(jsonDecode(verbirichaJson), ref);
      final nielContactList = (PartialContactList()
            ..addFollow(franzapProfile)
            ..addFollow(verbirichaProfile))
          .dummySign(nielProfile.pubkey);

      await storage.save({franzapProfile, verbirichaProfile, nielContactList});

      expect(nielProfile.contactList.value!.following.toList(),
          {franzapProfile, verbirichaProfile});
    });
  });
}

final verbirichaJson = '''
{
        "content": "{\\"created_at\\":1712395725,\\"name\\":\\"verbiricha\\",\\"picture\\":\\"https://npub107jk7htfv243u0x5ynn43scq9wrxtaasmrwwa8lfu2ydwag6cx2quqncxg.blossom.band/3d84787d7284c879429eb0c8e6dcae0bf94cc50456d4046adf33cf040f8f5504.jpg\\",\\"about\\":\\"nostr flâneur\\",\\"lud16\\":\\"verbiricha@coinos.io\\",\\"nip05\\":\\"verbiricha@habla.news\\",\\"display_name\\":\\"verbiricha\\",\\"website\\":\\"https://chachi.chat\\",\\"banner\\":\\"https://npub107jk7htfv243u0x5ynn43scq9wrxtaasmrwwa8lfu2ydwag6cx2quqncxg.blossom.band/5caca44f65ee8e3f92737787e0aa453119a5564760104b244a5ed7f06f8322a7.jpg\\",\\"pubkey\\":\\"7fa56f5d6962ab1e3cd424e758c3002b8665f7b0d8dcee9fe9e288d7751ac194\\",\\"npub\\":\\"npub107jk7htfv243u0x5ynn43scq9wrxtaasmrwwa8lfu2ydwag6cx2quqncxg\\",\\"categories\\":[\\"Development & Engineering\\"],\\"displayName\\":\\"verbiricha\\"}",
        "created_at": 1743454587,
        "id": "81b04899af11bd0d7e4fbb5cee9349231fd247fb3d76e5944acf8cb6d58b2562",
        "kind": 0,
        "pubkey": "7fa56f5d6962ab1e3cd424e758c3002b8665f7b0d8dcee9fe9e288d7751ac194",
        "sig": "7fbba68e9821ed12bef2808e4b652e8f055fbbe6c1a8733a1c09f6fd52dc776c18edaad9e0213dfd4c512e55ca6367a2c0b24c5852fa1be2f0dac7393101d769",
        "tags": [
            [
                "alt",
                "User profile for verbiricha"
            ]
        ]
    }
''';

final franzapJson = '''
{
        "content": "{\\"about\\":\\"Building nostr:npub10r8xl2njyepcw2zwv3a6dyufj4e4ajx86hz6v4ehu4gnpupxxp7stjt2p8 - nostr:npub1kpt95rv4q3mcz8e4lamwtxq7men6jprf49l7asfac9lnv2gda0lqdknhmz - https://npub.world - The Business of Freedom Tech Podcast | BA 🇦🇷\\",\\"banner\\":\\"https://image.nostr.build/aa036e73c2ab116c24d4a31965c8796b0af2f78f2356d1d2fb61dae60547687b.jpg\\",\\"display_name\\":\\"franzap\\",\\"lud16\\":\\"zapstore@getalby.com\\",\\"name\\":\\"franzap\\",\\"nip05\\":\\"fran@zapstore.dev\\",\\"picture\\":\\"https://nostr.build/i/nostr.build_1732d9a6cd9614c6c4ac3b8f0ee4a8242e9da448e2aacb82e7681d9d0bc36568.jpg\\",\\"website\\":\\"https://zapstore.dev\\",\\"displayName\\":\\"franzap\\",\\"pubkey\\":\\"726a1e261cc6474674e8285e3951b3bb139be9a773d1acf49dc868db861a1c11\\",\\"npub\\":\\"npub1wf4pufsucer5va8g9p0rj5dnhvfeh6d8w0g6eayaep5dhps6rsgs43dgh9\\",\\"created_at\\":1732842936}",
        "created_at": 1740787196,
        "id": "3e37c0988907994d6c898f43111c8d2b856e2646fb9c849476c334b363848151",
        "kind": 0,
        "pubkey": "726a1e261cc6474674e8285e3951b3bb139be9a773d1acf49dc868db861a1c11",
        "sig": "935415d8175249d4838154643e018d8b7c98655c1b0e096e883e972f421ffed7f70b4a799c570f24d42c31d29cb175a0623fb11e99bad6aa29d130e71338a8b5",
        "tags": [
            [
                "alt",
                "User profile for franzap"
            ]
        ]
    }
''';

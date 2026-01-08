/// Common test pubkeys
class Pubkeys {
  static const niel =
      'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be';
  static const verbiricha =
      '7fa56f5d6962ab1e3cd424e758c3002b8665f7b0d8dcee9fe9e288d7751ac194';
  static const franzap =
      '726a1e261cc6474674e8285e3951b3bb139be9a773d1acf49dc868db861a1c11';
}

/// Sample JSON events for testing deserialization
class SampleEvents {
  static final verbirichaProfile = '''
{
  "content": "{\\"created_at\\":1712395725,\\"name\\":\\"verbiricha\\",\\"picture\\":\\"https://example.com/pic.jpg\\",\\"about\\":\\"nostr flâneur\\",\\"lud16\\":\\"verbiricha@coinos.io\\",\\"nip05\\":\\"verbiricha@habla.news\\"}",
  "created_at": 1743454587,
  "id": "81b04899af11bd0d7e4fbb5cee9349231fd247fb3d76e5944acf8cb6d58b2562",
  "kind": 0,
  "pubkey": "${Pubkeys.verbiricha}",
  "sig": "7fbba68e9821ed12bef2808e4b652e8f055fbbe6c1a8733a1c09f6fd52dc776c18edaad9e0213dfd4c512e55ca6367a2c0b24c5852fa1be2f0dac7393101d769",
  "tags": [["alt", "User profile for verbiricha"]]
}
''';

  static final franzapProfile = '''
{
  "content": "{\\"about\\":\\"Building apps\\",\\"name\\":\\"franzap\\",\\"nip05\\":\\"fran@zapstore.dev\\",\\"picture\\":\\"https://example.com/pic.jpg\\"}",
  "created_at": 1740787196,
  "id": "3e37c0988907994d6c898f43111c8d2b856e2646fb9c849476c334b363848151",
  "kind": 0,
  "pubkey": "${Pubkeys.franzap}",
  "sig": "935415d8175249d4838154643e018d8b7c98655c1b0e096e883e972f421ffed7f70b4a799c570f24d42c31d29cb175a0623fb11e99bad6aa29d130e71338a8b5",
  "tags": [["alt", "User profile for franzap"]]
}
''';

  /// Video event with imeta tags (NIP-71)
  static Map<String, dynamic> videoWithImeta({
    String pubkey = Pubkeys.niel,
    String id = 'testvideo123',
  }) =>
      {
        'id': id,
        'pubkey': pubkey,
        'created_at': 1671217411,
        'kind': 21,
        'content': 'Test video with imeta tags',
        'tags': [
          ['title', 'Test Video'],
          [
            'imeta',
            'url https://videos.example.com/video-1080p.mp4',
            'm video/mp4',
            'dim 1920x1080',
          ],
          [
            'imeta',
            'url https://videos.example.com/video-720p.mp4',
            'm video/mp4',
            'dim 1280x720',
          ],
        ],
        'sig': 'testsig123',
      };

  /// Video event with both imeta and url tags
  static Map<String, dynamic> videoMixedTags({
    String pubkey = Pubkeys.niel,
  }) =>
      {
        'id': 'mixedvideo123',
        'pubkey': pubkey,
        'created_at': 1671217411,
        'kind': 21,
        'content': 'Video with mixed tags',
        'tags': [
          ['url', 'https://old-style.com/video.mp4'],
          ['imeta', 'url https://new-style.com/video.mp4', 'm video/mp4'],
        ],
        'sig': 'testsig123',
      };
}


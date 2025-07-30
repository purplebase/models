part of models;

/// Simple relay information data class for relay servers
class RelayInfoData {
  final String name;
  final String description;
  final List<int> supportedNips;
  final String software;
  final String version;
  final String contact;
  final String? pubkey;
  final String? icon;
  final Map<String, dynamic>? supportedNipsDetails;

  const RelayInfoData({
    required this.name,
    required this.description,
    required this.supportedNips,
    required this.software,
    required this.version,
    required this.contact,
    this.pubkey,
    this.icon,
    this.supportedNipsDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'supported_nips': supportedNips,
      'software': software,
      'version': version,
      'contact': contact,
      if (pubkey != null) 'pubkey': pubkey,
      if (icon != null) 'icon': icon,
      if (supportedNipsDetails != null)
        'supported_nips_details': supportedNipsDetails,
    };
  }

  String toJson() => jsonEncode(toMap());
}

/// Relay information according to NIP-11
class RelayInfo extends RegularModel<RelayInfo> {
  final String name;
  final String description;
  final List<int> supportedNips;
  final String software;
  final String version;
  final String contact;
  final String? icon;
  final Map<String, dynamic>? supportedNipsDetails;

  /// The relay's pubkey from the content (different from the event's pubkey)
  String? get relayPubkey {
    final content = _parseContent(event.content);
    return content['pubkey'] as String?;
  }

  RelayInfo._(
    Ref ref,
    ImmutableEvent event, {
    required this.name,
    required this.description,
    required this.supportedNips,
    required this.software,
    required this.version,
    required this.contact,
    this.icon,
    this.supportedNipsDetails,
  }) : super._(ref, event);

  factory RelayInfo.fromMap(Map<String, dynamic> map, Ref ref) {
    final event = ImmutableEvent<RelayInfo>(map);
    final content = _parseContent(event.content);

    return RelayInfo._(
      ref,
      event,
      name: content['name'] as String? ?? '',
      description: content['description'] as String? ?? '',
      supportedNips:
          (content['supported_nips'] as List<dynamic>?)?.cast<int>() ?? [],
      software: content['software'] as String? ?? '',
      version: content['version'] as String? ?? '',
      contact: content['contact'] as String? ?? '',
      icon: content['icon'] as String?,
      supportedNipsDetails:
          content['supported_nips_details'] as Map<String, dynamic>?,
    );
  }

  static Map<String, dynamic> _parseContent(String content) {
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'content': jsonEncode({
        'name': name,
        'description': description,
        'supported_nips': supportedNips,
        'software': software,
        'version': version,
        'contact': contact,
        if (icon != null) 'icon': icon,
        if (supportedNipsDetails != null)
          'supported_nips_details': supportedNipsDetails,
      }),
    };
  }

  String toJson() => jsonEncode(toMap());
}

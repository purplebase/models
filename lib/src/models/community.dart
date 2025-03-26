import 'package:models/models.dart';

class Community {
  final String npub;
  final String profilePicUrl;
  final String communityName;
  final String? description;
  final List<Profile>? inYourNetwork;

  const Community({
    required this.npub,
    required this.profilePicUrl,
    required this.communityName,
    this.description,
    this.inYourNetwork,
  });
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.avatarBase64,
    required this.messagePublicKey,
  });

  final String id;
  final String username;
  final String? avatarBase64;
  final String? messagePublicKey;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: (json['username'] as String?)?.trim() ?? '',
      avatarBase64: (json['avatar_base64'] as String?)?.trim(),
      messagePublicKey: (json['message_public_key'] as String?)?.trim(),
    );
  }
}

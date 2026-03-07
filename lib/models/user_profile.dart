class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.avatarBase64,
    required this.messagePublicKey,
    this.trust,
  });

  final String id;
  final String username;
  final String? avatarBase64;
  final String? messagePublicKey;
  final UserTrustSnapshot? trust;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: (json['username'] as String?)?.trim() ?? '',
      avatarBase64: (json['avatar_base64'] as String?)?.trim(),
      messagePublicKey: (json['message_public_key'] as String?)?.trim(),
      trust: json['trust'] is Map<String, dynamic>
          ? UserTrustSnapshot.fromJson(json['trust'] as Map<String, dynamic>)
          : null,
    );
  }
}

class UserTrustSnapshot {
  const UserTrustSnapshot({
    required this.activeDays,
    required this.level,
    required this.contributionScore,
    required this.rank,
    required this.nextLevelActiveDays,
    required this.levelProgressPercent,
    required this.dailyOutboundMessagesEnforced,
    required this.dailyOutboundMessagesLimit,
    required this.dailyOutboundMessagesSent,
    required this.dailyOutboundMessagesRemaining,
    required this.dailyAttachmentSendsEnforced,
    required this.dailyAttachmentSendLimit,
    required this.dailyAttachmentSendsSent,
    required this.dailyAttachmentSendsRemaining,
    required this.allowedAttachmentTypes,
  });

  final int activeDays;
  final int level;
  final int contributionScore;
  final String rank;
  final int? nextLevelActiveDays;
  final int levelProgressPercent;
  final bool dailyOutboundMessagesEnforced;
  final int? dailyOutboundMessagesLimit;
  final int dailyOutboundMessagesSent;
  final int? dailyOutboundMessagesRemaining;
  final bool dailyAttachmentSendsEnforced;
  final int? dailyAttachmentSendLimit;
  final int dailyAttachmentSendsSent;
  final int? dailyAttachmentSendsRemaining;
  final List<String> allowedAttachmentTypes;

  factory UserTrustSnapshot.fromJson(Map<String, dynamic> json) {
    return UserTrustSnapshot(
      activeDays: _readInt(json['active_days']),
      level: _readInt(json['level']),
      contributionScore: _readInt(json['contribution_score']),
      rank: (json['rank'] as String?)?.trim() ?? '',
      nextLevelActiveDays: _readNullableInt(json['next_level_active_days']),
      levelProgressPercent: _readInt(json['level_progress_percent']),
      dailyOutboundMessagesEnforced:
          json['daily_outbound_messages_enforced'] == true,
      dailyOutboundMessagesLimit: _readNullableInt(
        json['daily_outbound_messages_limit'],
      ),
      dailyOutboundMessagesSent: _readInt(json['daily_outbound_messages_sent']),
      dailyOutboundMessagesRemaining: _readNullableInt(
        json['daily_outbound_messages_remaining'],
      ),
      dailyAttachmentSendsEnforced:
          json['daily_attachment_sends_enforced'] == true,
      dailyAttachmentSendLimit: _readNullableInt(
        json['daily_attachment_send_limit'],
      ),
      dailyAttachmentSendsSent: _readInt(json['daily_attachment_sends_sent']),
      dailyAttachmentSendsRemaining: _readNullableInt(
        json['daily_attachment_sends_remaining'],
      ),
      allowedAttachmentTypes:
          (json['allowed_attachment_types'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false),
    );
  }

  static int _readInt(Object? value) => _readNullableInt(value) ?? 0;

  static int? _readNullableInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}

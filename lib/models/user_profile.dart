class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.avatarBase64,
    required this.description,
    required this.messagePublicKey,
    this.guild,
  });

  final String id;
  final String username;
  final String? avatarBase64;
  final String? description;
  final String? messagePublicKey;
  final UserGuildSnapshot? guild;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: (json['username'] as String?)?.trim() ?? '',
      avatarBase64: (json['avatar_base64'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
      messagePublicKey: (json['message_public_key'] as String?)?.trim(),
      guild: json['guild'] is Map<String, dynamic>
          ? UserGuildSnapshot.fromJson(json['guild'] as Map<String, dynamic>)
          : null,
    );
  }
}

enum TrustMilestoneKind { levelUp, rankUp, unlockAttachmentType }

class GuildMilestoneNotification {
  const GuildMilestoneNotification({
    required this.kind,
    required this.badgeLabel,
    required this.headlineKey,
    required this.detailKey,
    required this.newValue,
    this.unlockedValue,
  });

  final TrustMilestoneKind kind;
  final String badgeLabel;
  final String headlineKey;
  final String detailKey;
  final String newValue;
  final String? unlockedValue;

  factory GuildMilestoneNotification.fromJson(Map<String, dynamic> json) {
    final kindStr = (json['kind'] as String?)?.trim() ?? '';
    final kind = switch (kindStr) {
      'rank_up' => TrustMilestoneKind.rankUp,
      'unlock_attachment_type' => TrustMilestoneKind.unlockAttachmentType,
      _ => TrustMilestoneKind.levelUp,
    };
    return GuildMilestoneNotification(
      kind: kind,
      badgeLabel: (json['badge_label'] as String?)?.trim() ?? '',
      headlineKey: (json['headline_key'] as String?)?.trim() ?? '',
      detailKey: (json['detail_key'] as String?)?.trim() ?? '',
      newValue: (json['new_value'] as String?)?.trim() ?? '',
      unlockedValue: (json['unlocked_value'] as String?)?.trim(),
    );
  }
}

class UserGuildSnapshot {
  const UserGuildSnapshot({
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
    required this.dailyFriendAddsEnforced,
    required this.dailyFriendAddLimit,
    required this.dailyFriendAddsSent,
    required this.dailyFriendAddsRemaining,
    required this.challengeState,
    this.pendingMilestoneNotification,
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
  final bool dailyFriendAddsEnforced;
  final int? dailyFriendAddLimit;
  final int dailyFriendAddsSent;
  final int? dailyFriendAddsRemaining;

  /// One of: "none", "challenged", "frozen".
  final String challengeState;
  final GuildMilestoneNotification? pendingMilestoneNotification;

  factory UserGuildSnapshot.fromJson(Map<String, dynamic> json) {
    return UserGuildSnapshot(
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
      dailyFriendAddsEnforced: json['daily_friend_adds_enforced'] == true,
      dailyFriendAddLimit: _readNullableInt(json['daily_friend_add_limit']),
      dailyFriendAddsSent: _readInt(json['daily_friend_adds_sent']),
      dailyFriendAddsRemaining: _readNullableInt(
        json['daily_friend_adds_remaining'],
      ),
      challengeState: (json['challenge_state'] as String?)?.trim() ?? 'none',
      pendingMilestoneNotification:
          json['pending_milestone_notification'] is Map<String, dynamic>
          ? GuildMilestoneNotification.fromJson(
              json['pending_milestone_notification'] as Map<String, dynamic>,
            )
          : null,
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

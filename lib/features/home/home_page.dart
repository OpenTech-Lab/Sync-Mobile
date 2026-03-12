import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';
import '../../ui/tokens/colors/app_palette.dart';
import '../../ui/components/atoms/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/planet_presets.dart';
import '../../models/chat_room.dart';
import '../../state/app_controller.dart';
import '../../services/server_health_service.dart';
import '../../state/conversation_messages_controller.dart';
import '../chats/chat_target_profile_page.dart';
import '../chats/room_detail_page.dart';
import '../profile/my_profile_page.dart';
import '../../state/unread_counts_controller.dart';
import '../../state/user_profile_controller.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({
    super.key,
    required this.serverUrl,
    required this.accessToken,
    required this.currentUserId,
    required this.currentUsername,
    required this.planetInfo,
    this.onOpenChat,
  });

  final String serverUrl;
  final String accessToken;
  final String currentUserId;
  final String? currentUsername;
  final PlanetInfo? planetInfo;
  final ValueChanged<String>? onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    final unreadCounts =
        ref.watch(unreadCountsProvider).value ?? const <String, int>{};
    final totalUnread = unreadCounts.values.fold(
      0,
      (sum, count) => sum + count,
    );
    final friendIds = ref.watch(friendIdsProvider).value ?? const <String>[];
    final planetLabel = resolvePlanetName(
      serverUrl: serverUrl,
      instanceName: planetInfo?.instanceName,
      fallbackName: l10n.settingsPlanetUnknownName,
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            _SectionLabel(text: l10n.myProfileTitle, ruleColor: ruleColor),
            _ProfileCard(
              serverUrl: serverUrl,
              accessToken: accessToken,
              currentUserId: currentUserId,
              currentUsername: currentUsername,
              inkColor: inkColor,
              mutedColor: AppPalette.neutral500,
            ),
            const SizedBox(height: 32),
            _RoomsSection(
              serverUrl: serverUrl,
              currentUserId: currentUserId,
              inkColor: inkColor,
              ruleColor: ruleColor,
              onOpenChat: onOpenChat,
            ),
            if (totalUnread > 0) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppPalette.danger700,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.homeUnreadSummary(totalUnread),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppPalette.danger700,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            _SectionLabel(
              text: l10n.friendsTitle(friendIds.length),
              ruleColor: ruleColor,
            ),
            if (friendIds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.noFriendsYet,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: inkColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.openChatsHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.neutral500,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: friendIds.length,
                itemBuilder: (ctx, i) {
                  final id = friendIds[i];
                  return _HomeFriendRow(
                    key: ValueKey(id),
                    serverUrl: serverUrl,
                    accessToken: accessToken,
                    currentUserId: currentUserId,
                    friendId: id,
                    planetLabel: planetLabel,
                    inkColor: inkColor,
                    onOpenChat: onOpenChat,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

String _displayNameOrFallback(String userId, String? displayName) {
  final normalized = (displayName ?? '').trim();
  if (normalized.isNotEmpty) {
    return normalized;
  }
  return userId.length >= 8 ? userId.substring(0, 8) : userId;
}

String? _normalizedHomeDescription(String? description) {
  final normalized = (description ?? '').trim();
  return normalized.isEmpty ? null : normalized;
}

Color _avatarToneColor(String id) {
  const palette = [
    AppPalette.avatarTone1,
    AppPalette.avatarTone2,
    AppPalette.avatarTone3,
    AppPalette.avatarTone4,
    AppPalette.avatarTone5,
    AppPalette.avatarTone6,
  ];
  final hash = id.codeUnits.fold(0, (a, b) => a ^ b);
  return palette[hash.abs() % palette.length];
}

class _HomeFriendRow extends ConsumerStatefulWidget {
  const _HomeFriendRow({
    super.key,
    required this.serverUrl,
    required this.accessToken,
    required this.currentUserId,
    required this.friendId,
    required this.planetLabel,
    required this.inkColor,
    this.onOpenChat,
  });

  final String serverUrl;
  final String accessToken;
  final String currentUserId;
  final String friendId;
  final String planetLabel;
  final Color inkColor;
  final ValueChanged<String>? onOpenChat;

  @override
  ConsumerState<_HomeFriendRow> createState() => _HomeFriendRowState();
}

class _HomeFriendRowState extends ConsumerState<_HomeFriendRow> {
  bool _syncStarted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_syncProfile());
  }

  @override
  void didUpdateWidget(covariant _HomeFriendRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.friendId != widget.friendId ||
        oldWidget.serverUrl != widget.serverUrl) {
      _syncStarted = false;
      unawaited(_syncProfile());
    }
  }

  Future<void> _syncProfile() async {
    if (_syncStarted) {
      return;
    }
    _syncStarted = true;

    final userId = widget.friendId.trim();
    if (userId.isEmpty) {
      return;
    }

    try {
      final accessToken =
          await ref
              .read(appControllerProvider.notifier)
              .ensureFreshAccessToken() ??
          widget.accessToken;
      final profile = await ref
          .read(remoteUserProfileServiceProvider)
          .getUserProfile(
            baseUrl: widget.serverUrl,
            accessToken: accessToken,
            userId: userId,
          );
      final prefs = ref.read(userProfilePreferencesProvider);
      final oldDisplayName = await prefs.readDisplayName(
        widget.serverUrl,
        userId,
      );
      final oldAvatar = await prefs.readAvatarBase64(widget.serverUrl, userId);
      final oldDescription = await prefs.readDescription(
        widget.serverUrl,
        userId,
      );
      await prefs.writeDisplayName(widget.serverUrl, userId, profile.username);
      await prefs.writeAvatarBase64(
        widget.serverUrl,
        userId,
        profile.avatarBase64,
      );
      await prefs.writeDescription(
        widget.serverUrl,
        userId,
        profile.description,
      );
      if (!mounted) {
        return;
      }
      if (profile.username.trim() != (oldDisplayName ?? '').trim()) {
        ref.invalidate(userDisplayNameProvider(userId));
      }
      if (profile.avatarBase64 != oldAvatar) {
        ref.invalidate(userAvatarBase64Provider(userId));
      }
      if ((profile.description?.trim() ?? '') !=
          (oldDescription ?? '').trim()) {
        ref.invalidate(userDescriptionProvider(userId));
      }
    } catch (_) {
      // Keep cached data when sync fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayName = _displayNameOrFallback(
      widget.friendId,
      ref.watch(userDisplayNameProvider(widget.friendId)).value,
    );
    final description = _normalizedHomeDescription(
      ref.watch(userDescriptionProvider(widget.friendId)).value,
    );
    final avatarBase64 = ref
        .watch(userAvatarBase64Provider(widget.friendId))
        .value;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: avatarBase64 != null
            ? Colors.transparent
            : _avatarToneColor(widget.friendId),
        child: avatarBase64 == null
            ? Text(
                widget.friendId.isEmpty
                    ? '?'
                    : (widget.friendId.length >= 2
                              ? widget.friendId.substring(0, 2)
                              : widget.friendId)
                          .toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AppPalette.white,
                ),
              )
            : ClipOval(
                child: SizedBox.expand(
                  child: Image.memory(
                    base64Decode(avatarBase64),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: widget.inkColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.planetLabel,
            style: TextStyle(
              fontSize: 10,
              color: AppPalette.neutral500,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      subtitle: description == null
          ? null
          : Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: AppPalette.neutral500,
                fontWeight: FontWeight.w300,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: () async {
        final prefs = ref.read(userProfilePreferencesProvider);
        final messages = await ref
            .read(chatRepositoryProvider)
            .listMessages(conversationId: widget.friendId, limit: 5000);
        final sentMessageCount = messages
            .where((message) => message.senderId == widget.currentUserId)
            .length;
        final friendAddedAt = await prefs.readFriendAddedAt(
          widget.serverUrl,
          widget.friendId,
        );
        int? guildLevel;
        String? guildRank;
        try {
          final accessToken =
              await ref
                  .read(appControllerProvider.notifier)
                  .ensureFreshAccessToken() ??
              widget.accessToken;
          final profile = await ref
              .read(remoteUserProfileServiceProvider)
              .getUserProfile(
                baseUrl: widget.serverUrl,
                accessToken: accessToken,
                userId: widget.friendId,
              );
          guildLevel = profile.guild?.level;
          guildRank = profile.guild?.rank;
        } catch (_) {
          // guild data is optional
        }
        if (!context.mounted) {
          return;
        }
        final action = await Navigator.of(context)
            .push<ChatTargetProfileAction>(
              MaterialPageRoute<ChatTargetProfileAction>(
                builder: (_) => ChatTargetProfileScreen(
                  serverUrl: widget.serverUrl,
                  userId: widget.friendId,
                  displayName: displayName,
                  displayHandle: widget.friendId,
                  avatarBase64: avatarBase64,
                  isFriend: true,
                  friendAddedAt: friendAddedAt,
                  sentMessageCount: sentMessageCount,
                  description: description,
                  level: guildLevel,
                  rank: guildRank,
                ),
              ),
            );
        if (!context.mounted || action == null) {
          ref.invalidate(friendTagCatalogProvider);
          ref.invalidate(friendTagMapProvider);
          ref.invalidate(friendTagsProvider(widget.friendId));
          return;
        }
        ref.invalidate(friendTagCatalogProvider);
        ref.invalidate(friendTagMapProvider);
        ref.invalidate(friendTagsProvider(widget.friendId));
        if (action == ChatTargetProfileAction.startChat) {
          widget.onOpenChat?.call(widget.friendId);
          return;
        }
        if (action != ChatTargetProfileAction.cancelFriend) {
          return;
        }
        await prefs.removeFriendId(widget.serverUrl, widget.friendId);
        ref.invalidate(friendIdsProvider);
        if (!context.mounted) {
          return;
        }
        showAppToast(context, l10n.friendRemoved);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Rooms section shown on the home tab.
// ---------------------------------------------------------------------------
class _RoomsSection extends ConsumerWidget {
  const _RoomsSection({
    required this.serverUrl,
    required this.currentUserId,
    required this.inkColor,
    required this.ruleColor,
    this.onOpenChat,
  });

  final String serverUrl;
  final String currentUserId;
  final Color inkColor;
  final Color ruleColor;
  final ValueChanged<String>? onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomConversationsProvider);
    final rooms = roomsAsync.valueOrNull ?? const <ChatRoom>[];
    if (rooms.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'Rooms', ruleColor: ruleColor),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: rooms.length,
          itemBuilder: (ctx, i) {
            final room = rooms[i];
            return _RoomRow(
              room: room,
              inkColor: inkColor,
              onTap: () async {
                final action = await Navigator.of(context)
                    .push<RoomDetailAction>(
                      MaterialPageRoute<RoomDetailAction>(
                        builder: (_) => RoomDetailPage(
                          serverUrl: serverUrl,
                          roomId: room.id,
                          currentUserId: currentUserId,
                        ),
                      ),
                    );
                if (!context.mounted || action == null) return;
                if (action == RoomDetailAction.startChat) {
                  onOpenChat?.call(room.conversationId);
                } else if (action == RoomDetailAction.left ||
                    action == RoomDetailAction.deleted) {
                  ref.invalidate(roomConversationsProvider);
                }
              },
            );
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.room,
    required this.inkColor,
    required this.onTap,
  });

  final ChatRoom room;
  final Color inkColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const palette = [
      AppPalette.avatarTone1,
      AppPalette.avatarTone2,
      AppPalette.avatarTone3,
      AppPalette.avatarTone4,
      AppPalette.avatarTone5,
      AppPalette.avatarTone6,
    ];
    final hash = room.name.codeUnits.fold(0, (a, b) => a ^ b);
    final avatarBg = palette[hash.abs() % palette.length];
    final initials = room.name.trim().isEmpty
        ? '#'
        : room.name.trim().substring(0, 1).toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: avatarBg,
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppPalette.white,
          ),
        ),
      ),
      title: Text(
        room.name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w300,
          color: inkColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: room.unreadCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppPalette.danger700,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${room.unreadCount}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppPalette.white,
                ),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.ruleColor});
  final String text;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 2.8,
              fontWeight: FontWeight.w400,
              color: AppPalette.neutral500,
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 1, color: ruleColor),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({
    required this.serverUrl,
    required this.accessToken,
    required this.currentUserId,
    required this.currentUsername,
    required this.inkColor,
    required this.mutedColor,
  });

  final String serverUrl;
  final String accessToken;
  final String currentUserId;
  final String? currentUsername;
  final Color inkColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final avatarBase64 = ref
        .watch(userAvatarBase64Provider(currentUserId))
        .value;
    final watchedUsername =
        ref.watch(userDisplayNameProvider(currentUserId)).value ??
        currentUsername;
    final description = _normalizedHomeDescription(
      ref.watch(userDescriptionProvider(currentUserId)).value,
    );
    final guild = ref.watch(myGuildSnapshotProvider).asData?.value;
    final displayName = _displayNameOrFallback(currentUserId, watchedUsername);

    const palette = [
      AppPalette.avatarTone1,
      AppPalette.avatarTone2,
      AppPalette.avatarTone3,
      AppPalette.avatarTone4,
      AppPalette.avatarTone5,
      AppPalette.avatarTone6,
    ];
    final hash = currentUserId.codeUnits.fold(0, (a, b) => a ^ b);
    final avatarColor = palette[hash.abs() % palette.length];

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MyProfileScreen(
              serverUrl: serverUrl,
              accessToken: accessToken,
              currentUserId: currentUserId,
              currentUsername: currentUsername,
            ),
          ),
        );
        ref.invalidate(userAvatarBase64Provider(currentUserId));
        ref.invalidate(userDisplayNameProvider(currentUserId));
        ref.invalidate(userDescriptionProvider(currentUserId));
      },
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: avatarBase64 != null
                ? Colors.transparent
                : avatarColor,
            child: avatarBase64 == null
                ? Text(
                    currentUserId.length >= 2
                        ? currentUserId.substring(0, 2).toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      color: AppPalette.white,
                    ),
                  )
                : ClipOval(
                    child: SizedBox.expand(
                      child: Image.memory(
                        base64Decode(avatarBase64),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        key: const ValueKey('home_profile_username'),
                        displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          color: inkColor,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (guild != null) ...[
                      const SizedBox(
                        key: ValueKey('home_profile_badge_gap'),
                        width: 8,
                      ),
                      _HomeGuildBadge(
                        key: const ValueKey('home_profile_level_badge'),
                        label: 'Lv ${guild.level}',
                        mutedColor: mutedColor,
                      ),
                      if (guild.rank.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _HomeGuildBadge(
                          key: const ValueKey('home_profile_rank_badge'),
                          label: guild.rank,
                          mutedColor: mutedColor,
                        ),
                      ],
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description ?? l10n.profileNoDescriptionYet,
                  style: TextStyle(
                    fontSize: 11,
                    color: mutedColor,
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w300,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small pill badge shown on the home profile card for level / rank.
// ---------------------------------------------------------------------------
class _HomeGuildBadge extends StatelessWidget {
  const _HomeGuildBadge({
    super.key,
    required this.label,
    required this.mutedColor,
  });
  final String label;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mutedColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: mutedColor,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dedicated dialog widget — owns its TextEditingController lifecycle so that
// dispose() is never called while the exit animation still uses the TextField.
// ---------------------------------------------------------------------------
class _UsernameEditDialog extends StatefulWidget {
  const _UsernameEditDialog({required this.initialValue});
  final String initialValue;

  @override
  State<_UsernameEditDialog> createState() => _UsernameEditDialogState();
}

class _UsernameEditDialogState extends State<_UsernameEditDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    return Dialog(
      backgroundColor: bgColor,
      surfaceTintColor: AppPalette.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.homeUsernameDialogTitle,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 2.8,
                color: AppPalette.neutral500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w300,
                color: inkColor,
              ),
              decoration: InputDecoration(
                hintText: l10n.homeUsernameHint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppPalette.neutral500.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w300,
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppPalette.neutral500),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
            ),
            const SizedBox(height: 28),
            Divider(height: 1, thickness: 1, color: ruleColor),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(
                      l10n.actionCancel,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppPalette.neutral500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(_ctrl.text.trim()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(
                      l10n.actionSave,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w500,
                        color: inkColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

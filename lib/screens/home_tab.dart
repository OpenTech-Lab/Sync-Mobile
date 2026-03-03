import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/planet_presets.dart';
import '../state/conversation_messages_controller.dart';
import 'chat_target_profile_screen.dart';
import 'my_profile_screen.dart';
import '../state/unread_counts_controller.dart';
import '../state/user_profile_controller.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({
    super.key,
    required this.serverUrl,
    required this.accessToken,
    required this.currentUserId,
    required this.currentUsername,
    this.onOpenChat,
  });

  final String serverUrl;
  final String accessToken;
  final String currentUserId;
  final String? currentUsername;
  final ValueChanged<String>? onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const mujiPaper   = Color(0xFFFAF9F6);
    const mujiPaperDk = Color(0xFF1E1C19);
    const mujiInk     = Color(0xFF2C2A27);
    const mujiInkDk   = Color(0xFFE8E4DC);
    const mujiMuted   = Color(0xFF8A8680);
    const mujiRule    = Color(0xFFDDD8CF);
    const mujiRuleDk  = Color(0xFF3A3730);

    final bgColor   = isDark ? mujiPaperDk : mujiPaper;
    final inkColor  = isDark ? mujiInkDk   : mujiInk;
    final ruleColor = isDark ? mujiRuleDk  : mujiRule;

    final unreadCounts =
        ref.watch(unreadCountsProvider).value ?? const <String, int>{};
    final totalUnread = unreadCounts.values.fold(
      0,
      (sum, count) => sum + count,
    );
    final friendIds = ref.watch(friendIdsProvider).value ?? const <String>[];
    final planetLabel = _planetNameFromServerUrl(serverUrl);

    String initials(String uuid) =>
        uuid.isEmpty ? '?' : uuid.substring(0, 2).toUpperCase();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            _SectionLabel(text: 'My Profile', ruleColor: ruleColor),
            _ProfileCard(
              serverUrl: serverUrl,
              accessToken: accessToken,
              currentUserId: currentUserId,
              currentUsername: currentUsername,
              inkColor: inkColor,
              mujiMuted: mujiMuted,
            ),
            const SizedBox(height: 32),
            if (totalUnread > 0) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF9B3A2A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$totalUnread unread ${totalUnread == 1 ? 'message' : 'messages'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9B3A2A),
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            _SectionLabel(
              text: 'Friends (${friendIds.length})',
              ruleColor: ruleColor,
            ),
            if (friendIds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No friends yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: inkColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Open Chats and start a conversation',
                      style: TextStyle(
                        fontSize: 12,
                        color: mujiMuted,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: friendIds.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: ruleColor,
                ),
                itemBuilder: (ctx, i) {
                  final id = friendIds[i];
                  final displayName = _displayNameOrFallback(
                    id,
                    ref.watch(userDisplayNameProvider(id)).value,
                  );
                  final description =
                      ref.watch(userDescriptionProvider(id)).value ?? '';
                  final avatarBase64 = ref
                      .watch(userAvatarBase64Provider(id))
                      .value;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: _mujiAvatarColor(id),
                      child: avatarBase64 == null
                          ? Text(
                              initials(id),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
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
                              color: inkColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          planetLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: mujiMuted,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    subtitle: Text(
                      description.trim().isEmpty
                          ? ''
                          : description.trim(),
                      style: TextStyle(
                        fontSize: 12,
                        color: mujiMuted,
                        fontWeight: FontWeight.w300,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      final prefs = ref.read(userProfilePreferencesProvider);
                      final messages = await ref
                          .read(chatRepositoryProvider)
                          .listMessages(conversationId: id, limit: 5000);
                      final sentMessageCount = messages
                          .where((message) => message.senderId == currentUserId)
                          .length;
                      final friendAddedAt = await prefs.readFriendAddedAt(id);
                      if (!context.mounted) {
                        return;
                      }
                      final action = await Navigator.of(
                        context,
                      ).push<ChatTargetProfileAction>(
                        MaterialPageRoute<ChatTargetProfileAction>(
                          builder: (_) => ChatTargetProfileScreen(
                            displayName: displayName,
                            displayHandle: id,
                            avatarBase64: avatarBase64,
                            isFriend: true,
                            friendAddedAt: friendAddedAt,
                            sentMessageCount: sentMessageCount,
                            description: description,
                            showActions: false,
                          ),
                        ),
                      );
                      if (!context.mounted ||
                          action != ChatTargetProfileAction.cancelFriend) {
                        return;
                      }
                      await prefs.removeFriendId(id);
                      ref.invalidate(friendIdsProvider);
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Friend removed')),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Color _mujiAvatarColor(String id) {
    // Warm muted tones consistent with Muji palette
    const palette = [
      Color(0xFF8A8069),
      Color(0xFF7A9080),
      Color(0xFF9B7B6E),
      Color(0xFF7D8A74),
      Color(0xFF8E8278),
      Color(0xFF7B8A8A),
    ];
    final hash = id.codeUnits.fold(0, (a, b) => a ^ b);
    return palette[hash.abs() % palette.length];
  }
}

String _displayNameOrFallback(String userId, String? displayName) {
  final normalized = (displayName ?? '').trim();
  if (normalized.isNotEmpty) {
    return normalized;
  }
  return userId.length >= 8 ? userId.substring(0, 8) : userId;
}

String _planetNameFromServerUrl(String serverUrl) {
  final normalized = serverUrl.trim();
  final preset = officialPlanetPresets.firstWhere(
    (item) => item.url.toLowerCase() == normalized.toLowerCase(),
    orElse: () => PlanetPreset(name: '', url: ''),
  );
  if (preset.name.isNotEmpty) {
    return preset.name;
  }
  final host = Uri.tryParse(normalized)?.host.trim() ?? '';
  if (host.isNotEmpty) {
    return host;
  }
  return normalized;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
    required this.ruleColor,
  });
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
              color: Color(0xFF8A8680),
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
    required this.mujiMuted,
  });

  final String serverUrl;
  final String accessToken;
  final String currentUserId;
  final String? currentUsername;
  final Color inkColor;
  final Color mujiMuted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarBase64 = ref
        .watch(userAvatarBase64Provider(currentUserId))
        .value;
    final displayName = (currentUsername ?? '').trim().isEmpty
        ? (currentUserId.length >= 8
              ? currentUserId.substring(0, 8)
              : currentUserId)
        : currentUsername!.trim();

    const palette = [
      Color(0xFF8A8069),
      Color(0xFF7A9080),
      Color(0xFF9B7B6E),
      Color(0xFF7D8A74),
      Color(0xFF8E8278),
      Color(0xFF7B8A8A),
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
      },
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: avatarColor,
            child: avatarBase64 == null
                ? Text(
                    currentUserId.length >= 2
                        ? currentUserId.substring(0, 2).toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
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
                Text(
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
                const SizedBox(height: 2),
                Text(
                  'View profile',
                  style: TextStyle(
                    fontSize: 11,
                    color: mujiMuted,
                    letterSpacing: 0.2,
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const mujiPaper   = Color(0xFFFAF9F6);
    const mujiPaperDk = Color(0xFF1E1C19);
    const mujiInk     = Color(0xFF2C2A27);
    const mujiInkDk   = Color(0xFFE8E4DC);
    const mujiMuted   = Color(0xFF8A8680);
    const mujiRule    = Color(0xFFDDD8CF);
    const mujiRuleDk  = Color(0xFF3A3730);

    final bgColor   = isDark ? mujiPaperDk : mujiPaper;
    final inkColor  = isDark ? mujiInkDk   : mujiInk;
    final ruleColor = isDark ? mujiRuleDk  : mujiRule;

    return Dialog(
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'USERNAME',
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 2.8,
                color: mujiMuted,
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
                hintText: '3–32 characters, a-z A-Z 0-9 . _ -',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: mujiMuted.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w300,
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: ruleColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: mujiMuted),
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
                      horizontal: 4, vertical: 4),
                    child: const Text(
                      'cancel',
                      style: TextStyle(
                        fontSize: 13,
                        color: mujiMuted,
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
                      horizontal: 4, vertical: 4),
                    child: Text(
                      'S A V E',
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

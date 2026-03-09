import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../models/chat_room.dart';
import '../../../services/local_chat_repository.dart';
import '../../../state/user_profile_controller.dart';
import '../../../ui/tokens/colors/app_palette.dart';
import '../models/outgoing_draft.dart';
import '../utils/chat_helpers.dart';
import 'quick_action_sheet.dart';

class ConversationStarter extends ConsumerWidget {
  const ConversationStarter({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.unreadCounts,
    required this.orderedConversationIds,
    required this.summariesById,
    required this.onQuickAction,
    required this.onOpenConversation,
    required this.onClearConversation,
    required this.onMarkAllRead,
    required this.onStartNewChat,
    required this.onAddFriend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Map<String, int> unreadCounts;
  final List<String> orderedConversationIds;
  final Map<String, ConversationSummary> summariesById;
  final ValueChanged<ChatQuickAction> onQuickAction;
  final ValueChanged<String> onOpenConversation;
  final Future<void> Function(String) onClearConversation;
  final Future<void> Function() onMarkAllRead;
  final VoidCallback onStartNewChat;
  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    final unreadConversationIds = orderedConversationIds
        .where((id) => (unreadCounts[id] ?? 0) > 0)
        .toList(growable: false);
    final chatConversationIds = orderedConversationIds
        .where((id) => (unreadCounts[id] ?? 0) == 0)
        .toList(growable: false);
    final hasAnyRows =
        unreadConversationIds.isNotEmpty || chatConversationIds.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      children: [
        // ── search + quick action ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autocorrect: false,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: inkColor,
                ),
                decoration: InputDecoration(
                  hintText: l10n.chatSearchHint,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: AppPalette.neutral500.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w300,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: ruleColor),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: ruleColor),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppPalette.neutral500),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                final action = await showModalBottomSheet<ChatQuickAction>(
                  context: context,
                  backgroundColor: bgColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  builder: (_) => QuickActionSheet(
                    inkColor: inkColor,
                    mutedColor: AppPalette.neutral500,
                    ruleColor: ruleColor,
                  ),
                );
                if (action != null) onQuickAction(action);
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.add, color: inkColor, size: 22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── unread section ──
        if (unreadConversationIds.isNotEmpty) ...[
          Row(
            children: [
              Text(
                l10n.chatUnreadHeader,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.4,
                  color: AppPalette.neutral500,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onMarkAllRead,
                child: Text(
                  l10n.chatMarkAllRead,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppPalette.neutral500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 1, color: ruleColor),
          const SizedBox(height: 4),
          ...unreadConversationIds.map(
            (userId) => _buildConversationRow(
              context,
              ref,
              userId,
              summariesById,
              inkColor,
              AppPalette.neutral500,
            ),
          ),
        ],

        if (hasAnyRows && chatConversationIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.chatChatsHeader,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 2.4,
              color: AppPalette.neutral500,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 1, color: ruleColor),
          const SizedBox(height: 4),
        ],

        if (!hasAnyRows)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              l10n.chatNoChatsYet,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: AppPalette.neutral500,
              ),
            ),
          )
        else
          ...chatConversationIds.map(
            (userId) => _buildConversationRow(
              context,
              ref,
              userId,
              summariesById,
              inkColor,
              AppPalette.neutral500,
            ),
          ),
      ],
    );
  }

  String _formatLastBody(String body, AppLocalizations l10n) {
    if (body.startsWith('[sticker:')) return l10n.chatSentASticker;
    if (body.startsWith('[media-data:')) return l10n.chatSentAnAttachment;
    return body;
  }

  Widget _buildConversationRow(
    BuildContext context,
    WidgetRef ref,
    String userId,
    Map<String, ConversationSummary> summariesById,
    Color inkColor,
    Color mutedColor,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final summary = summariesById[userId];
    final unreadCount = unreadCounts[userId] ?? 0;
    final isRoom = summary?.isRoom ?? isRoomConversationId(userId);
    final displayNameAsync = isRoom
        ? null
        : ref.watch(userDisplayNameProvider(userId));
    final avatarBase64Async = isRoom
        ? null
        : ref.watch(userAvatarBase64Provider(userId));
    final displayName = isRoom
        ? ((summary?.title?.trim().isNotEmpty ?? false)
              ? summary!.title!.trim()
              : l10n.chatDefaultRoom)
        : displayNameOrFallback(userId, displayNameAsync?.value);

    // avatar warm palette
    const palette = [
      AppPalette.avatarTone1,
      AppPalette.avatarTone2,
      AppPalette.avatarTone3,
      AppPalette.avatarTone4,
      AppPalette.avatarTone5,
      AppPalette.avatarTone6,
    ];
    final hash = userId.codeUnits.fold(0, (a, b) => a ^ b);
    final avatarColor = palette[hash.abs() % palette.length];
    final subtitle = summary == null
        ? null
        : (summary.lastBody.trim().isNotEmpty
              ? _formatLastBody(summary.lastBody, l10n)
              : isRoom
              ? l10n.chatDefaultRoom
              : null);

    final rowContent = Column(
      children: [
        InkWell(
          onTap: () => onOpenConversation(userId),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                // avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: !isRoom && avatarBase64Async?.value != null
                      ? Colors.transparent
                      : avatarColor,
                  child: isRoom
                      ? const Icon(
                          Icons.group_outlined,
                          size: 18,
                          color: AppPalette.white,
                        )
                      : avatarBase64Async?.value == null
                      ? Text(
                          userId.length >= 2
                              ? userId.substring(0, 2).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppPalette.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                          ),
                        )
                      : ClipOval(
                          child: SizedBox.expand(
                            child: Image.memory(
                              base64Decode(avatarBase64Async!.value!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: inkColor,
                        ),
                      ),
                      if (summary != null)
                        Text(
                          subtitle ?? _formatLastBody(summary.lastBody, l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: mutedColor,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (summary != null)
                      Text(
                        timeLabel(summary.lastAt),
                        style: TextStyle(fontSize: 11, color: mutedColor),
                      ),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppPalette.danger700,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$unreadCount',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppPalette.danger700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (isRoom) return rowContent;

    return Dismissible(
      key: ValueKey('convo_$userId'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppPalette.danger700.withValues(alpha: 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline, color: AppPalette.white, size: 20),
            const SizedBox(height: 2),
            Text(
              l10n.chatClearHistory,
              style: const TextStyle(
                color: AppPalette.white,
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await onClearConversation(userId);
        return true;
      },
      onDismissed: (_) {},
      child: rowContent,
    );
  }
}

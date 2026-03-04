import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';
import '../../ui/tokens/colors/app_palette.dart';

enum ChatTargetProfileAction { startChat, addFriend, cancelFriend }

class ChatTargetProfileScreen extends StatelessWidget {
  const ChatTargetProfileScreen({
    super.key,
    required this.displayName,
    required this.displayHandle,
    required this.avatarBase64,
    this.isFriend = false,
    this.friendAddedAt,
    this.sentMessageCount,
    this.hasChatHistory,
    this.description,
    this.showActions = true,
  });

  final String displayName;
  final String displayHandle;
  final String? avatarBase64;
  final bool isFriend;
  final DateTime? friendAddedAt;
  final int? sentMessageCount;
  final bool? hasChatHistory;
  final String? description;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    const palette = [
      AppPalette.avatarTone1,
      AppPalette.avatarTone2,
      AppPalette.avatarTone3,
      AppPalette.avatarTone4,
      AppPalette.avatarTone5,
      AppPalette.avatarTone6,
    ];
    final hash = displayHandle.codeUnits.fold(0, (a, b) => a ^ b);
    final avatarBg = palette[hash.abs() % palette.length];

    final initials = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().substring(0, 1).toUpperCase();
    final shouldShowChatShortcut = (hasChatHistory ?? false) == false;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppPalette.neutral500),
        actions: [
          if (isFriend)
            GestureDetector(
              onTap: () => Navigator.of(
                context,
              ).pop(ChatTargetProfileAction.cancelFriend),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  l10n.chatTargetCancelFriend,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppPalette.danger700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        children: [
          // ── avatar + name ──
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: avatarBg,
              child: avatarBase64 == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        color: AppPalette.white,
                        fontWeight: FontWeight.w300,
                        fontSize: 22,
                      ),
                    )
                  : ClipOval(
                      child: SizedBox.expand(
                        child: Image.memory(
                          base64Decode(avatarBase64!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(
                            initials,
                            style: const TextStyle(
                              color: AppPalette.white,
                              fontWeight: FontWeight.w300,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w300,
              color: inkColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            displayHandle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppPalette.neutral500,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),
          Divider(height: 1, color: ruleColor),
          const SizedBox(height: 20),

          // ── actions row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isFriend)
                GestureDetector(
                  onTap: () => Navigator.of(
                    context,
                  ).pop(ChatTargetProfileAction.addFriend),
                  child: Text(
                    l10n.chatTargetAddFriend,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w500,
                      color: inkColor,
                    ),
                  ),
                )
              else
                Text(
                  l10n.chatTargetFriend,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: AppPalette.success700,
                  ),
                ),
              if (showActions) ...[
                const SizedBox(width: 32),
                GestureDetector(
                  onTap: () => Navigator.of(
                    context,
                  ).pop(ChatTargetProfileAction.startChat),
                  child: Text(
                    l10n.chatTargetStartChat,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w500,
                      color: inkColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (shouldShowChatShortcut) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () => Navigator.of(
                  context,
                ).pop(ChatTargetProfileAction.startChat),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 16, color: inkColor),
                    const SizedBox(width: 8),
                    Text(
                      l10n.chatTargetStartChat,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w500,
                        color: inkColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── friend since ──
          if (isFriend && friendAddedAt != null) ...[
            const SizedBox(height: 28),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 16),
            Text(
              l10n.chatTargetFriendSince,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.4,
                color: AppPalette.neutral500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _friendSinceLabel(friendAddedAt!),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: inkColor,
              ),
            ),
          ],

          // ── messages sent ──
          if (isFriend && sentMessageCount != null) ...[
            const SizedBox(height: 20),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 16),
            Text(
              l10n.chatTargetMessagesSent,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.4,
                color: AppPalette.neutral500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$sentMessageCount',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: inkColor,
              ),
            ),
          ],

          // ── description ──
          if ((description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 16),
            Text(
              l10n.chatTargetAbout,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.4,
                color: AppPalette.neutral500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description!.trim(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: inkColor,
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _friendSinceLabel(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

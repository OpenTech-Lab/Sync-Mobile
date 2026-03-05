import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobile/l10n/app_localizations.dart';
import '../../ui/tokens/colors/app_palette.dart';
import '../../ui/components/atoms/outline_action_button.dart';

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
    this.description,
  });

  final String displayName;
  final String displayHandle;
  final String? avatarBase64;
  final bool isFriend;
  final DateTime? friendAddedAt;
  final int? sentMessageCount;
  final String? description;

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
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlineActionButton(
                label: l10n.chatTargetCancelFriend,
                borderColor: AppPalette.danger700.withValues(alpha: 0.45),
                textColor: AppPalette.danger700,
                variant: OutlineActionVariant.danger,
                compact: true,
                onTap: () => Navigator.of(context)
                    .pop(ChatTargetProfileAction.cancelFriend),
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
          if (isFriend) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedUserCheck01,
                  size: 13,
                  color: AppPalette.success700,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.chatTargetFriend,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: AppPalette.success700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          Divider(height: 1, color: ruleColor),
          const SizedBox(height: 20),

          // ── actions row ──
          Row(
            children: [
              Expanded(
                child: OutlineActionButton(
                  label: l10n.chatTargetAddFriend,
                  borderColor: ruleColor,
                  textColor: inkColor,
                  disabled: isFriend,
                  onTap: () => Navigator.of(context)
                      .pop(ChatTargetProfileAction.addFriend),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlineActionButton(
                  label: l10n.chatTargetStartChat,
                  borderColor: ruleColor,
                  textColor: inkColor,
                  onTap: () => Navigator.of(context)
                      .pop(ChatTargetProfileAction.startChat),
                ),
              ),
            ],
          ),

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

enum _ProfileActionVariant { normal, danger }

/// Bordered spaced-caps action button used on the target profile page.
/// Handles normal (neutral border) and danger (red border + tint) variants.
/// Set [disabled] to grey it out without removing it from the layout.
/// Set [compact] for AppBar-sized padding; otherwise uses row padding.
class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.label,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
    this.variant = _ProfileActionVariant.normal,
    this.disabled = false,
    this.compact = false,
  });

  final String label;
  final Color borderColor;
  final Color textColor;
  final VoidCallback? onTap;
  final _ProfileActionVariant variant;
  final bool disabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDanger = variant == _ProfileActionVariant.danger;
    final effectiveBorder =
        disabled ? borderColor.withValues(alpha: 0.3) : borderColor;
    final effectiveText =
        disabled ? textColor.withValues(alpha: 0.35) : textColor;
    final bgColor =
        isDanger ? AppPalette.danger700.withValues(alpha: 0.06) : null;
    final splashColor =
        isDanger ? AppPalette.danger700.withValues(alpha: 0.12) : null;
    final radius = compact ? 8.0 : 10.0;
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.symmetric(vertical: 14);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: effectiveBorder, width: 1),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: splashColor,
          child: Padding(
            padding: padding,
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w500,
                color: effectiveText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

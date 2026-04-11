import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../ui/tokens/colors/app_palette.dart';
import '../models/outgoing_draft.dart';

class QuickActionSheet extends StatelessWidget {
  const QuickActionSheet({
    super.key,
    required this.inkColor,
    required this.mutedColor,
    required this.ruleColor,
  });

  final Color inkColor;
  final Color mutedColor;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context)!.chatQuickNewHeader,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.8,
                color: mutedColor,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: ruleColor),
            SheetItem(
              label: AppLocalizations.of(context)!.chatQuickNewRoom,
              inkColor: inkColor,
              onTap: () => Navigator.of(context).pop(ChatQuickAction.newRoom),
            ),
            Divider(height: 1, color: ruleColor),
            SheetItem(
              label: AppLocalizations.of(context)!.chatQuickFriendOrStart,
              inkColor: inkColor,
              onTap: () =>
                  Navigator.of(context).pop(ChatQuickAction.newFriendOrChat),
            ),
            Divider(height: 1, color: ruleColor),
            SheetItem(
              label: AppLocalizations.of(context)!.chatQuickScanFriendQr,
              inkColor: inkColor,
              onTap: () =>
                  Navigator.of(context).pop(ChatQuickAction.scanFriendQr),
            ),
            Divider(height: 1, color: ruleColor),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  AppLocalizations.of(context)!.actionCancel,
                  style: TextStyle(
                    fontSize: 12,
                    color: mutedColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SheetItem extends StatelessWidget {
  const SheetItem({
    super.key,
    required this.label,
    required this.inkColor,
    required this.onTap,
  });

  final String label;
  final Color inkColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: inkColor,
          ),
        ),
      ),
    );
  }
}

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
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
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: AppPalette.danger700,
            fontSize: 11,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

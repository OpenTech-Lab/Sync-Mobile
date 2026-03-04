import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../core/extensions/context_extensions.dart';
import '../atoms/app_icon.dart';
import '../atoms/app_text.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.totalUnread = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final int totalUnread;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabIcons = [
      Icons.home_outlined,
      Icons.public_outlined,
      Icons.chat_bubble_outline,
      Icons.settings_outlined,
    ];
    final tabLabels = [
      l10n.tabHome,
      l10n.tabPlanet,
      l10n.tabChats,
      l10n.tabSettings,
    ];

    return Container(
      color: context.colors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeArea(
            top: false,
            child: SizedBox(
              height: 48,
              child: Row(
                children: List.generate(tabIcons.length, (i) {
                  final selected = selectedIndex == i;
                  final isChats = i == 2;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected)
                              AppIcon(tabIcons[i], size: 19)
                            else
                              AppText(
                                tabLabels[i],
                                variant: AppTextVariant.body,
                                style: TextStyle(
                                  fontWeight: FontWeight.w300,
                                  color: context.colors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            if (isChats && totalUnread > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: context.colors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

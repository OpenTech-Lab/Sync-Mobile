import 'package:flutter/cupertino.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../core/extensions/context_extensions.dart';
import '../atoms/app_icon.dart';
import '../atoms/app_text.dart';

const _navSelectionAnimationDuration = Duration(milliseconds: 220);
const _navPressAnimationDuration = Duration(milliseconds: 120);

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
    final usesEnglishLabels =
        Localizations.localeOf(context).languageCode == 'en';
    final tabs = [
      _BottomNavTabData(
        activeIcon: CupertinoIcons.house_fill,
        inactiveIcon: CupertinoIcons.house,
        label: _displayTabLabel(l10n.tabHome, uppercase: usesEnglishLabels),
      ),
      _BottomNavTabData(
        activeIcon: CupertinoIcons.bubble_left_bubble_right_fill,
        inactiveIcon: CupertinoIcons.bubble_left_bubble_right,
        label: _displayTabLabel(l10n.tabChats, uppercase: usesEnglishLabels),
      ),
      _BottomNavTabData(
        activeIcon: CupertinoIcons.globe,
        inactiveIcon: CupertinoIcons.globe,
        label: _displayTabLabel(l10n.tabPlanet, uppercase: usesEnglishLabels),
      ),
    ];

    return Container(
      color: context.colors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: List.generate(tabs.length, (i) {
                  final selected = selectedIndex == i;
                  final isChats = i == 1;
                  return Expanded(
                    child: Center(
                      child: _BottomNavButton(
                        tab: tabs[i],
                        selected: selected,
                        showUnreadIndicator: isChats && totalUnread > 0,
                        onTap: () => onTap(i),
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

String _displayTabLabel(String raw, {required bool uppercase}) {
  final trimmed = raw.trim();
  if (!uppercase || trimmed.isEmpty) {
    return trimmed;
  }
  return trimmed.toUpperCase();
}

class _BottomNavTabData {
  const _BottomNavTabData({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });

  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
}

class _BottomNavButton extends StatefulWidget {
  const _BottomNavButton({
    required this.tab,
    required this.selected,
    required this.showUnreadIndicator,
    required this.onTap,
  });

  final _BottomNavTabData tab;
  final bool selected;
  final bool showUnreadIndicator;
  final VoidCallback onTap;

  @override
  State<_BottomNavButton> createState() => _BottomNavButtonState();
}

class _BottomNavButtonState extends State<_BottomNavButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.colors.onSurface.withValues(
      alpha: widget.selected ? 0.08 : 0,
    );
    final iconColor = widget.selected
        ? context.colors.onSurface
        : context.colors.muted;
    final labelColor = widget.selected
        ? context.colors.onSurface
        : context.colors.muted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: _navPressAnimationDuration,
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.95 : 1,
        child: AnimatedContainer(
          duration: _navSelectionAnimationDuration,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: widget.selected ? 12 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: _navSelectionAnimationDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      );
                    },
                    child: AppIcon(
                      widget.selected
                          ? widget.tab.activeIcon
                          : widget.tab.inactiveIcon,
                      key: ValueKey(
                        '${widget.tab.label}_${widget.selected ? 'active' : 'inactive'}',
                      ),
                      size: widget.selected ? 20 : 19,
                      color: iconColor,
                    ),
                  ),
                  if (widget.showUnreadIndicator)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: context.colors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              AnimatedSize(
                duration: _navSelectionAnimationDuration,
                curve: Curves.easeOutCubic,
                child: widget.selected
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 8),
                          AppText(
                            widget.tab.label,
                            variant: AppTextVariant.body,
                            style: TextStyle(
                              fontWeight: FontWeight.w300,
                              color: labelColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

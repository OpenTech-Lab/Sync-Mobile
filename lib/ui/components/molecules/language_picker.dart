import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../state/app_locale_controller.dart';
import '../../tokens/colors/app_palette.dart';

class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appLocaleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;

    String labelFor(AppLocaleOption option) {
      final l10n = AppLocalizations.of(context)!;
      return switch (option) {
        AppLocaleOption.system => l10n.languageSystem,
        AppLocaleOption.english => l10n.languageEnglish,
        AppLocaleOption.traditionalChinese => l10n.languageTraditionalChinese,
      };
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showLanguageSheet(context, ref, selected),
      child: compact
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.translate_rounded,
                    size: 14,
                    color: AppPalette.neutral500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labelFor(selected),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: inkColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: AppPalette.neutral500,
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.translate_rounded,
                    size: 16,
                    color: AppPalette.neutral500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labelFor(selected),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: inkColor,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppPalette.neutral500,
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _showLanguageSheet(
    BuildContext context,
    WidgetRef ref,
    AppLocaleOption selected,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.languageLabel.toUpperCase(),
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
                _LanguageOptionRow(
                  label: l10n.languageSystem,
                  selected: selected == AppLocaleOption.system,
                  inkColor: inkColor,
                  onTap: () {
                    ref
                        .read(appLocaleProvider.notifier)
                        .setOption(AppLocaleOption.system);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                _LanguageOptionRow(
                  label: l10n.languageEnglish,
                  selected: selected == AppLocaleOption.english,
                  inkColor: inkColor,
                  onTap: () {
                    ref
                        .read(appLocaleProvider.notifier)
                        .setOption(AppLocaleOption.english);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                _LanguageOptionRow(
                  label: l10n.languageTraditionalChinese,
                  selected: selected == AppLocaleOption.traditionalChinese,
                  inkColor: inkColor,
                  onTap: () {
                    ref
                        .read(appLocaleProvider.notifier)
                        .setOption(AppLocaleOption.traditionalChinese);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LanguageOptionRow extends StatelessWidget {
  const _LanguageOptionRow({
    required this.label,
    required this.selected,
    required this.inkColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color inkColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w300,
                  color: selected ? inkColor : AppPalette.neutral500,
                ),
              ),
            ),
            if (selected)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppPalette.success700,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

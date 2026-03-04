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
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(appLocaleProvider);

    String labelFor(AppLocaleOption option) {
      return switch (option) {
        AppLocaleOption.system => l10n.languageSystem,
        AppLocaleOption.english => l10n.languageEnglish,
        AppLocaleOption.traditionalChinese => l10n.languageTraditionalChinese,
      };
    }

    return PopupMenuButton<AppLocaleOption>(
      tooltip: l10n.languageLabel,
      onSelected: (next) =>
          ref.read(appLocaleProvider.notifier).setOption(next),
      itemBuilder: (_) => [
        PopupMenuItem<AppLocaleOption>(
          value: AppLocaleOption.system,
          child: Text(labelFor(AppLocaleOption.system)),
        ),
        PopupMenuItem<AppLocaleOption>(
          value: AppLocaleOption.english,
          child: Text(labelFor(AppLocaleOption.english)),
        ),
        PopupMenuItem<AppLocaleOption>(
          value: AppLocaleOption.traditionalChinese,
          child: Text(labelFor(AppLocaleOption.traditionalChinese)),
        ),
      ],
      child: compact
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: AppPalette.neutral300),
                borderRadius: BorderRadius.circular(4),
              ),
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
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppPalette.neutral500,
                    ),
                  ),
                ],
              ),
            )
          : Row(
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.neutral500,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppPalette.neutral500,
                ),
              ],
            ),
    );
  }
}

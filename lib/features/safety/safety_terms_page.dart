import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../ui/tokens/colors/app_palette.dart';
import 'safety_policy.dart';

Future<void> showSafetyTermsSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final backgroundColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
  final textColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
  final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: backgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (sheetContext) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  safetyTermsTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: ruleColor),
                const SizedBox(height: 12),
                Expanded(
                  child: Markdown(
                    data: safetyTermsMarkdown,
                    styleSheet:
                        MarkdownStyleSheet.fromTheme(
                          Theme.of(sheetContext),
                        ).copyWith(
                          p: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: textColor,
                            fontWeight: FontWeight.w300,
                          ),
                          h1: TextStyle(
                            fontSize: 20,
                            height: 1.4,
                            color: textColor,
                            fontWeight: FontWeight.w400,
                          ),
                          h2: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                          listBullet: TextStyle(color: textColor),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class SafetyTermsScreen extends StatefulWidget {
  const SafetyTermsScreen({
    super.key,
    required this.isSubmitting,
    required this.onAccept,
    required this.onSignOut,
  });

  final bool isSubmitting;
  final Future<void> Function() onAccept;
  final Future<void> Function() onSignOut;

  @override
  State<SafetyTermsScreen> createState() => _SafetyTermsScreenState();
}

class _SafetyTermsScreenState extends State<SafetyTermsScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppPalette.neutral900
        : AppPalette.neutral50;
    final textColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          safetyTermsTitle,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: textColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: widget.isSubmitting ? null : widget.onSignOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Review and agree before entering chats, rooms, or profiles.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppPalette.neutral500,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: ruleColor),
              const SizedBox(height: 12),
              Expanded(
                child: Markdown(
                  data: safetyTermsMarkdown,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: textColor,
                          fontWeight: FontWeight.w300,
                        ),
                        h1: TextStyle(
                          fontSize: 20,
                          height: 1.4,
                          color: textColor,
                          fontWeight: FontWeight.w400,
                        ),
                        h2: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        listBullet: TextStyle(color: textColor),
                      ),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _agreed,
                onChanged: widget.isSubmitting
                    ? null
                    : (value) => setState(() => _agreed = value == true),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'I agree to the Terms of Use and Safety Policy.',
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: !_agreed || widget.isSubmitting
                    ? null
                    : widget.onAccept,
                child: widget.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Agree and continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

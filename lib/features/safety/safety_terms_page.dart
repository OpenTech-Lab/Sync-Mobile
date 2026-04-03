import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../core/extensions/context_extensions.dart';
import 'safety_policy.dart';

Future<void> showSafetyTermsSheet(BuildContext context) {
  final colors = context.colors;
  final typography = context.appTypography;
  final ruleColor = colors.border;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
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
                Text(safetyTermsTitle, style: typography.title),
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
                          p: typography.body.copyWith(height: 1.6),
                          h1: typography.display.copyWith(height: 1.4),
                          h2: typography.label.copyWith(
                            fontSize: 14,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                          listBullet: typography.body,
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
    final colors = context.colors;
    final typography = context.appTypography;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(safetyTermsTitle, style: typography.body),
        actions: [
          TextButton(
            onPressed: widget.isSubmitting ? null : widget.onSignOut,
            style: TextButton.styleFrom(
              foregroundColor: colors.muted,
              textStyle: typography.label,
            ),
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
                style: typography.body.copyWith(
                  color: colors.muted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: colors.border),
              const SizedBox(height: 12),
              Expanded(
                child: Markdown(
                  data: safetyTermsMarkdown,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: typography.body.copyWith(height: 1.6),
                        h1: typography.display.copyWith(height: 1.4),
                        h2: typography.label.copyWith(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                        listBullet: typography.body,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: widget.isSubmitting
                    ? null
                    : () => setState(() => _agreed = !_agreed),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _agreed
                        ? colors.onSurface.withValues(alpha: 0.06)
                        : Colors.transparent,
                    border: Border.all(
                      color: _agreed ? colors.onSurface : colors.border,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color:
                              _agreed ? colors.onSurface : Colors.transparent,
                          border: Border.all(
                            color: _agreed ? colors.onSurface : colors.border,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: _agreed
                            ? Icon(
                                Icons.check,
                                size: 13,
                                color: colors.surface,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'I agree to the Terms of Use and Safety Policy.',
                          style: typography.body.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
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

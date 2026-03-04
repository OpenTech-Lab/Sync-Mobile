import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../tokens/colors/app_palette.dart';

class SimpleMarkdownText extends StatelessWidget {
  const SimpleMarkdownText({
    super.key,
    required this.markdown,
    required this.baseStyle,
    this.maxParagraphs,
  });

  final String markdown;
  final TextStyle baseStyle;
  final int? maxParagraphs;

  @override
  Widget build(BuildContext context) {
    final renderedMarkdown = _clipMarkdownByParagraphs(markdown, maxParagraphs);
    return MarkdownBody(
      data: renderedMarkdown,
      styleSheet: MarkdownStyleSheet(
        p: baseStyle,
        h1: baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14) + 3,
          fontWeight: FontWeight.w400,
        ),
        h2: baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14) + 2,
          fontWeight: FontWeight.w400,
        ),
        h3: baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) + 1),
        listBullet: baseStyle.copyWith(color: AppPalette.neutral500),
        code: baseStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: AppPalette.neutral300,
        ),
        a: baseStyle.copyWith(
          color: baseStyle.color,
          decoration: TextDecoration.underline,
        ),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppPalette.neutral300, width: 1),
          ),
        ),
        blockSpacing: 6,
        listIndent: 24,
      ),
    );
  }

  String _clipMarkdownByParagraphs(String source, int? max) {
    if (max == null || max <= 0) {
      return source;
    }

    final lines = source.replaceAll('\r\n', '\n').split('\n');
    var shown = 0;
    final kept = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        kept.add(line);
        continue;
      }
      if (shown >= max) {
        break;
      }
      kept.add(line);
      shown += 1;
    }
    return kept.join('\n').trimRight();
  }
}

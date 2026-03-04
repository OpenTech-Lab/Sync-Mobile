import 'package:flutter/material.dart';

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
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];
    var shownParagraphs = 0;

    for (final line in lines) {
      if (maxParagraphs != null && shownParagraphs >= maxParagraphs!) {
        break;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      if (trimmed.startsWith('### ')) {
        widgets.add(
          _buildRichText(
            trimmed.substring(4),
            baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) + 1),
          ),
        );
        shownParagraphs += 1;
        continue;
      }
      if (trimmed.startsWith('## ')) {
        widgets.add(
          _buildRichText(
            trimmed.substring(3),
            baseStyle.copyWith(
              fontSize: (baseStyle.fontSize ?? 14) + 2,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
        shownParagraphs += 1;
        continue;
      }
      if (trimmed.startsWith('# ')) {
        widgets.add(
          _buildRichText(
            trimmed.substring(2),
            baseStyle.copyWith(
              fontSize: (baseStyle.fontSize ?? 14) + 3,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
        shownParagraphs += 1;
        continue;
      }

      if (trimmed.startsWith('- ')) {
        widgets.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 8),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppPalette.neutral500,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: _buildRichText(trimmed.substring(2), baseStyle),
              ),
            ],
          ),
        );
        shownParagraphs += 1;
        continue;
      }

      widgets.add(_buildRichText(trimmed, baseStyle));
      shownParagraphs += 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: item,
              ))
          .toList(growable: false),
    );
  }

  Widget _buildRichText(String input, TextStyle style) {
    return RichText(
      text: TextSpan(
        style: style,
        children: _parseInline(input, style),
      ),
    );
  }

  List<TextSpan> _parseInline(String raw, TextStyle style) {
    final spans = <TextSpan>[];
    var cursor = 0;

    while (cursor < raw.length) {
      final boldStart = raw.indexOf('**', cursor);
      final codeStart = raw.indexOf('`', cursor);
      final italicStart = raw.indexOf('*', cursor);

      final candidates = [
        if (boldStart >= cursor) boldStart,
        if (codeStart >= cursor) codeStart,
        if (italicStart >= cursor) italicStart,
      ];
      if (candidates.isEmpty) {
        spans.add(TextSpan(text: raw.substring(cursor)));
        break;
      }

      final next = candidates.reduce((a, b) => a < b ? a : b);
      if (next > cursor) {
        spans.add(TextSpan(text: raw.substring(cursor, next)));
      }

      if (next == boldStart) {
        final end = raw.indexOf('**', next + 2);
        if (end > next) {
          spans.add(
            TextSpan(
              text: raw.substring(next + 2, end),
              style: style.copyWith(fontWeight: FontWeight.w500),
            ),
          );
          cursor = end + 2;
          continue;
        }
      }

      if (next == codeStart) {
        final end = raw.indexOf('`', next + 1);
        if (end > next) {
          spans.add(
            TextSpan(
              text: raw.substring(next + 1, end),
              style: style.copyWith(
                fontFamily: 'monospace',
                backgroundColor: AppPalette.neutral200,
              ),
            ),
          );
          cursor = end + 1;
          continue;
        }
      }

      if (next == italicStart) {
        final end = raw.indexOf('*', next + 1);
        if (end > next) {
          spans.add(
            TextSpan(
              text: raw.substring(next + 1, end),
              style: style.copyWith(fontStyle: FontStyle.italic),
            ),
          );
          cursor = end + 1;
          continue;
        }
      }

      spans.add(TextSpan(text: raw.substring(next, next + 1)));
      cursor = next + 1;
    }

    return spans;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/conversation_notes_controller.dart';
import '../../ui/tokens/colors/app_palette.dart';

class ConversationNotePage extends ConsumerStatefulWidget {
  const ConversationNotePage({
    super.key,
    required this.conversationId,
    required this.conversationName,
  });

  final String conversationId;
  final String conversationName;

  @override
  ConsumerState<ConversationNotePage> createState() =>
      _ConversationNotePageState();
}

class _ConversationNotePageState extends ConsumerState<ConversationNotePage> {
  late final TextEditingController _controller;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(conversationNoteProvider(widget.conversationId).notifier)
        .save(_controller.text);
    setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final l10n = AppLocalizations.of(context)!;

    final noteAsync = ref.watch(
      conversationNoteProvider(widget.conversationId),
    );

    // Populate text controller once when data first loads.
    noteAsync.whenData((note) {
      if (!_dirty && _controller.text.isEmpty && note != null) {
        _controller.text = note.content;
      }
    });

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
        iconTheme: IconThemeData(color: AppPalette.neutral500),
        title: Text(
          l10n.chatNotes,
          style: TextStyle(color: inkColor),
        ),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _save,
              child: Text(
                l10n.actionSave,
                style: TextStyle(color: inkColor),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: TextStyle(color: inkColor),
          cursorColor: AppPalette.neutral500,
          decoration: InputDecoration(
            hintText: l10n.chatNotesHint,
            hintStyle: TextStyle(
              color: AppPalette.neutral500.withValues(alpha: 0.6),
            ),
            border: InputBorder.none,
          ),
          onChanged: (_) {
            if (!_dirty) setState(() => _dirty = true);
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/conversation_notes_controller.dart';
import '../../ui/components/atoms/outline_action_button.dart';
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
  bool _loaded = false;
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
    if (mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;
    final l10n = AppLocalizations.of(context)!;

    // Populate text controller once when data first loads.
    ref.watch(conversationNoteProvider(widget.conversationId)).whenData((note) {
      if (!_loaded) {
        _loaded = true;
        if (note != null) {
          _controller.text = note.content;
          _controller.selection = TextSelection.collapsed(
            offset: note.content.length,
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppPalette.neutral500),
        actions: [
          if (_dirty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlineActionButton(
                label: l10n.actionSave,
                borderColor: ruleColor,
                textColor: inkColor,
                compact: true,
                onTap: _save,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
        children: [
          Text(
            l10n.chatNotes.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 2.4,
              color: AppPalette.neutral500,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.conversationName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: AppPalette.neutral500,
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: ruleColor),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            maxLines: null,
            minLines: 12,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w300,
              color: inkColor,
              height: 1.7,
            ),
            cursorColor: AppPalette.neutral500,
            decoration: InputDecoration(
              hintText: l10n.chatNotesHint,
              hintStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w300,
                color: AppPalette.neutral500.withValues(alpha: 0.55),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) {
              if (!_dirty) setState(() => _dirty = true);
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/todo_item.dart';
import '../../state/conversation_notes_controller.dart';
import '../../ui/components/atoms/outline_action_button.dart';
import '../../ui/tokens/colors/app_palette.dart';

class ConversationTodosPage extends ConsumerStatefulWidget {
  const ConversationTodosPage({
    super.key,
    required this.conversationId,
    required this.conversationName,
  });

  final String conversationId;
  final String conversationName;

  @override
  ConsumerState<ConversationTodosPage> createState() =>
      _ConversationTodosPageState();
}

class _ConversationTodosPageState
    extends ConsumerState<ConversationTodosPage> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await ref
        .read(conversationTodosProvider(widget.conversationId).notifier)
        .add(text);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppPalette.neutral900 : AppPalette.neutral50;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;
    final ruleColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;
    final l10n = AppLocalizations.of(context)!;

    final todos = ref
            .watch(conversationTodosProvider(widget.conversationId))
            .value ??
        const <TodoItem>[];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppPalette.neutral500),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.chatTodos.toUpperCase(),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    color: AppPalette.neutral500,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: ruleColor),
                const SizedBox(height: 14),

                // ── input row ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: inkColor,
                        ),
                        cursorColor: AppPalette.neutral500,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _add(),
                        decoration: InputDecoration(
                          hintText: l10n.chatTodosHint,
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: AppPalette.neutral500.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w300,
                          ),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: ruleColor),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: ruleColor),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppPalette.neutral500,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlineActionButton(
                      label: l10n.chatTodosAddAction,
                      borderColor: ruleColor,
                      textColor: inkColor,
                      compact: true,
                      onTap: _add,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: ruleColor),
              ],
            ),
          ),

          // ── todo list ──
          Expanded(
            child: todos.isEmpty
                ? Center(
                    child: Text(
                      l10n.chatTodosEmptyHint,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: AppPalette.neutral500,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: todos.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: ruleColor),
                    itemBuilder: (context, index) {
                      final todo = todos[index];
                      return _TodoRow(
                        key: ValueKey(todo.id),
                        todo: todo,
                        inkColor: inkColor,
                        ruleColor: ruleColor,
                        onToggle: () => ref
                            .read(
                              conversationTodosProvider(
                                widget.conversationId,
                              ).notifier,
                            )
                            .toggle(todo.id),
                        onDelete: () => ref
                            .read(
                              conversationTodosProvider(
                                widget.conversationId,
                              ).notifier,
                            )
                            .delete(todo.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    super.key,
    required this.todo,
    required this.inkColor,
    required this.ruleColor,
    required this.onToggle,
    required this.onDelete,
  });

  final TodoItem todo;
  final Color inkColor;
  final Color ruleColor;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final doneColor = AppPalette.neutral500;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 14, 16, 14),
        child: Row(
          children: [
            Icon(
              todo.isDone
                  ? Icons.check_circle_outline_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: todo.isDone ? doneColor : inkColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                todo.text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: todo.isDone ? doneColor : inkColor,
                  decoration: todo.isDone ? TextDecoration.lineThrough : null,
                  decorationColor: doneColor,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 16,
                color: AppPalette.neutral500,
              ),
              onPressed: onDelete,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

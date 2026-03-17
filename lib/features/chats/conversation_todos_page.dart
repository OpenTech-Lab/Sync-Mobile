import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/todo_item.dart';
import '../../state/conversation_notes_controller.dart';
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

    final todosAsync = ref.watch(
      conversationTodosProvider(widget.conversationId),
    );
    final todos = todosAsync.value ?? const <TodoItem>[];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: AppPalette.transparent,
        iconTheme: IconThemeData(color: AppPalette.neutral500),
        title: Text(l10n.chatTodos, style: TextStyle(color: inkColor)),
      ),
      body: Column(
        children: [
          // Input row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    style: TextStyle(color: inkColor),
                    cursorColor: AppPalette.neutral500,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      hintText: l10n.chatTodosHint,
                      hintStyle: TextStyle(
                        color: AppPalette.neutral500.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _add,
                  child: Text(
                    l10n.chatTodosAddAction,
                    style: TextStyle(color: inkColor),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: ruleColor),
          // Todo list
          Expanded(
            child: todos.isEmpty
                ? Center(
                    child: Text(
                      l10n.chatTodosEmptyHint,
                      style: TextStyle(color: AppPalette.neutral500),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: todos.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: ruleColor),
                    itemBuilder: (context, index) {
                      final todo = todos[index];
                      return _TodoTile(
                        key: ValueKey(todo.id),
                        todo: todo,
                        inkColor: inkColor,
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

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    super.key,
    required this.todo,
    required this.inkColor,
    required this.onToggle,
    required this.onDelete,
  });

  final TodoItem todo;
  final Color inkColor;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              todo.isDone
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              color: todo.isDone
                  ? AppPalette.neutral500
                  : inkColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                todo.text,
                style: TextStyle(
                  color: todo.isDone
                      ? AppPalette.neutral500
                      : inkColor,
                  decoration: todo.isDone
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: AppPalette.neutral500),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

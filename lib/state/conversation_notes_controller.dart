import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation_note.dart';
import '../models/todo_item.dart';
import '../services/local_chat_repository.dart';
import 'conversation_messages_controller.dart';

// ── Note ────────────────────────────────────────────────────────────────────

final conversationNoteProvider =
    AsyncNotifierProviderFamily<ConversationNoteController, ConversationNote?, String>(
      ConversationNoteController.new,
    );

class ConversationNoteController
    extends FamilyAsyncNotifier<ConversationNote?, String> {
  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  @override
  Future<ConversationNote?> build(String conversationId) {
    ref.watch(chatRepositoryProvider);
    return _repository.readNote(conversationId);
  }

  Future<void> save(String content) async {
    final note = ConversationNote(
      conversationId: arg,
      content: content,
      updatedAt: DateTime.now().toUtc(),
    );
    await _repository.saveNote(note);
    state = AsyncData(note);
  }
}

// ── Todos ────────────────────────────────────────────────────────────────────

final conversationTodosProvider =
    AsyncNotifierProviderFamily<ConversationTodosController, List<TodoItem>, String>(
      ConversationTodosController.new,
    );

class ConversationTodosController
    extends FamilyAsyncNotifier<List<TodoItem>, String> {
  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  @override
  Future<List<TodoItem>> build(String conversationId) {
    ref.watch(chatRepositoryProvider);
    return _repository.listTodos(conversationId);
  }

  Future<void> add(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = state.value ?? [];
    final maxOrder = current.isEmpty
        ? 0
        : current.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b);
    final random = Random.secure().nextInt(1000000);
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    final item = TodoItem(
      id: 't_${micros}_$random',
      conversationId: arg,
      text: trimmed,
      isDone: false,
      sortOrder: maxOrder + 1,
      createdAt: DateTime.now().toUtc(),
    );
    await _repository.upsertTodo(item);
    await _reload();
  }

  Future<void> toggle(String id) async {
    final current = state.value ?? [];
    final item = current.firstWhere((e) => e.id == id);
    await _repository.upsertTodo(item.copyWith(isDone: !item.isDone));
    await _reload();
  }

  Future<void> delete(String id) async {
    await _repository.deleteTodo(id);
    await _reload();
  }

  Future<void> _reload() async {
    final items = await _repository.listTodos(arg);
    state = AsyncData(items);
  }
}

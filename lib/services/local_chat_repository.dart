import 'dart:math';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/chat_room.dart';
import '../models/conversation_note.dart';
import '../models/local_chat_message.dart';
import '../models/todo_item.dart';
import 'encrypted_database.dart';

class ConversationSummary {
  const ConversationSummary({
    required this.conversationId,
    required this.lastBody,
    required this.lastAt,
    this.title,
    this.memberCount,
    this.unreadCount = 0,
  });
  final String conversationId;
  final String lastBody;
  final DateTime lastAt;
  final String? title;
  final int? memberCount;
  final int unreadCount;

  bool get isRoom => isRoomConversationId(conversationId);
}

abstract class ChatRepository {
  Future<List<LocalChatMessage>> listMessages({
    required String conversationId,
    int limit,
  });

  Future<void> addMessage({
    required String conversationId,
    required String senderId,
    required String body,
  });

  Future<void> replaceMessage(LocalChatMessage message);

  Future<void> upsertMessages(List<LocalChatMessage> messages);

  Future<List<LocalChatMessage>> listAllMessages();

  Future<void> replaceAllMessages(List<LocalChatMessage> messages);

  Future<void> clearConversation(String conversationId);

  Future<List<ConversationSummary>> listConversations();

  Future<List<ChatRoom>> listRooms();

  Future<ChatRoom?> readRoom(String roomId);

  Future<void> replaceRooms(List<ChatRoom> rooms);

  Future<void> updateRoomUnreadCount({
    required String roomId,
    required int unreadCount,
  });

  Future<ConversationNote?> readNote(String conversationId);

  Future<void> saveNote(ConversationNote note);

  Future<List<TodoItem>> listTodos(String conversationId);

  Future<void> upsertTodo(TodoItem todo);

  Future<void> deleteTodo(String todoId);

  Future<void> replaceTodos(String conversationId, List<TodoItem> todos);
}

// ── In-memory fallback for Flutter Web (sqflite_sqlcipher is native-only) ───
class InMemoryChatRepository implements ChatRepository {
  final _store = <String, List<LocalChatMessage>>{};
  final _rooms = <String, ChatRoom>{};
  final _notes = <String, ConversationNote>{};
  final _todos = <String, List<TodoItem>>{};

  @override
  Future<List<LocalChatMessage>> listMessages({
    required String conversationId,
    int limit = 100,
  }) async {
    final sorted = [...(_store[conversationId] ?? const <LocalChatMessage>[])]
      ..sort((a, b) {
        final byCreatedAt = b.createdAt.compareTo(a.createdAt);
        if (byCreatedAt != 0) {
          return byCreatedAt;
        }
        return b.id.compareTo(a.id);
      });
    return sorted.take(limit).toList(growable: false);
  }

  @override
  Future<void> addMessage({
    required String conversationId,
    required String senderId,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final message = LocalChatMessage(
      id: 'm_${DateTime.now().toUtc().microsecondsSinceEpoch}_${Random.secure().nextInt(1000000)}',
      conversationId: conversationId,
      senderId: senderId,
      body: trimmed,
      createdAt: DateTime.now().toUtc(),
    );
    (_store[conversationId] ??= []).add(message);
  }

  @override
  Future<void> replaceMessage(LocalChatMessage message) async {
    final list = _store[message.conversationId] ??= [];
    final idx = list.indexWhere((existing) => existing.id == message.id);
    if (idx == -1) {
      list.add(message);
    } else {
      list[idx] = message;
    }
  }

  @override
  Future<void> upsertMessages(List<LocalChatMessage> messages) async {
    for (final m in messages) {
      final list = _store[m.conversationId] ??= [];
      final idx = list.indexWhere((e) => e.id == m.id);
      if (idx == -1) {
        list.add(m);
      } else {
        list[idx] = m;
      }
    }
  }

  @override
  Future<List<LocalChatMessage>> listAllMessages() async {
    return _store.values.expand((l) => l).toList();
  }

  @override
  Future<void> replaceAllMessages(List<LocalChatMessage> messages) async {
    _store.clear();
    for (final m in messages) {
      (_store[m.conversationId] ??= []).add(m);
    }
  }

  @override
  Future<void> clearConversation(String conversationId) async {
    _store.remove(conversationId);
  }

  @override
  Future<List<ConversationSummary>> listConversations() async {
    final summaries = <String, ConversationSummary>{};
    for (final entry in _store.entries) {
      if (entry.value.isEmpty) continue;
      final sorted = [...entry.value]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final roomId = tryParseRoomId(entry.key);
      final room = roomId == null ? null : _rooms[roomId];
      // Skip room conversations whose room no longer exists (e.g. after delete).
      if (roomId != null && room == null) continue;
      summaries[entry.key] = ConversationSummary(
        conversationId: entry.key,
        lastBody: sorted.first.body,
        lastAt: sorted.first.createdAt,
        title: room?.name,
        memberCount: room?.memberCount,
        unreadCount: room?.unreadCount ?? 0,
      );
    }

    for (final room in _rooms.values) {
      summaries.putIfAbsent(
        room.conversationId,
        () => ConversationSummary(
          conversationId: room.conversationId,
          lastBody: room.lastMessagePreview ?? '',
          lastAt: room.lastMessageAt ?? room.updatedAt,
          title: room.name,
          memberCount: room.memberCount,
          unreadCount: room.unreadCount,
        ),
      );
    }

    final values = summaries.values.toList(growable: false)
      ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return values;
  }

  @override
  Future<List<ChatRoom>> listRooms() async {
    final rooms = _rooms.values.toList(growable: false)
      ..sort((a, b) {
        final aTs = a.lastMessageAt ?? a.updatedAt;
        final bTs = b.lastMessageAt ?? b.updatedAt;
        return bTs.compareTo(aTs);
      });
    return rooms;
  }

  @override
  Future<ChatRoom?> readRoom(String roomId) async {
    return _rooms[roomId];
  }

  @override
  Future<void> replaceRooms(List<ChatRoom> rooms) async {
    _rooms
      ..clear()
      ..addEntries(rooms.map((room) => MapEntry(room.id, room)));
  }

  @override
  Future<void> updateRoomUnreadCount({
    required String roomId,
    required int unreadCount,
  }) async {
    final room = _rooms[roomId];
    if (room == null) {
      return;
    }
    _rooms[roomId] = room.copyWith(unreadCount: unreadCount);
  }

  @override
  Future<ConversationNote?> readNote(String conversationId) async {
    return _notes[conversationId];
  }

  @override
  Future<void> saveNote(ConversationNote note) async {
    _notes[note.conversationId] = note;
  }

  @override
  Future<List<TodoItem>> listTodos(String conversationId) async {
    final items = [...(_todos[conversationId] ?? <TodoItem>[])];
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  @override
  Future<void> upsertTodo(TodoItem todo) async {
    final list = _todos[todo.conversationId] ??= [];
    final idx = list.indexWhere((e) => e.id == todo.id);
    if (idx == -1) {
      list.add(todo);
    } else {
      list[idx] = todo;
    }
  }

  @override
  Future<void> deleteTodo(String todoId) async {
    for (final list in _todos.values) {
      list.removeWhere((e) => e.id == todoId);
    }
  }

  @override
  Future<void> replaceTodos(
    String conversationId,
    List<TodoItem> todos,
  ) async {
    _todos[conversationId] = [...todos];
  }
}

class LocalChatRepository implements ChatRepository {
  LocalChatRepository({
    required String serverUrl,
    EncryptedDatabase? encryptedDatabase,
  }) : _encryptedDatabase =
           encryptedDatabase ?? EncryptedDatabase(serverUrl: serverUrl);

  final EncryptedDatabase _encryptedDatabase;

  @override
  Future<List<LocalChatMessage>> listMessages({
    required String conversationId,
    int limit = 100,
  }) async {
    final db = await _encryptedDatabase.open();
    final rows = await db.query(
      'local_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows
        .map((row) => LocalChatMessage.fromMap(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<void> addMessage({
    required String conversationId,
    required String senderId,
    required String body,
  }) async {
    final normalizedBody = body.trim();
    if (normalizedBody.isEmpty) {
      return;
    }

    final message = LocalChatMessage(
      id: _generateMessageId(),
      conversationId: conversationId,
      senderId: senderId,
      body: normalizedBody,
      createdAt: DateTime.now().toUtc(),
    );

    final db = await _encryptedDatabase.open();
    await db.insert('local_messages', message.toMap());
  }

  @override
  Future<void> replaceMessage(LocalChatMessage message) async {
    final db = await _encryptedDatabase.open();
    await db.insert(
      'local_messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> upsertMessages(List<LocalChatMessage> messages) async {
    if (messages.isEmpty) {
      return;
    }

    final db = await _encryptedDatabase.open();
    await db.transaction((txn) async {
      for (final message in messages) {
        await txn.insert(
          'local_messages',
          message.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  @override
  Future<void> clearConversation(String conversationId) async {
    final db = await _encryptedDatabase.open();
    await db.delete(
      'local_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  @override
  Future<List<LocalChatMessage>> listAllMessages() async {
    final db = await _encryptedDatabase.open();
    final rows = await db.query(
      'local_messages',
      orderBy: 'created_at DESC',
      limit: 5000,
    );
    return rows
        .map((row) => LocalChatMessage.fromMap(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<void> replaceAllMessages(List<LocalChatMessage> messages) async {
    final db = await _encryptedDatabase.open();
    await db.transaction((txn) async {
      await txn.delete('local_messages');
      for (final message in messages) {
        await txn.insert('local_messages', message.toMap());
      }
    });
  }

  @override
  Future<List<ConversationSummary>> listConversations() async {
    final db = await _encryptedDatabase.open();
    final rows = await db.query(
      'local_messages',
      columns: ['conversation_id', 'body', 'created_at'],
      orderBy: 'created_at DESC',
      limit: 5000,
    );

    final summaries = <String, ConversationSummary>{};
    final seenConversationIds = <String>{};

    for (final row in rows) {
      final map = Map<String, Object?>.from(row);
      final conversationId = map['conversation_id'] as String;
      if (seenConversationIds.contains(conversationId)) {
        continue;
      }

      seenConversationIds.add(conversationId);
      final roomId = tryParseRoomId(conversationId);
      final room = roomId == null ? null : await readRoom(roomId);
      // Skip room conversations whose room no longer exists (e.g. after delete).
      if (roomId != null && room == null) continue;
      summaries[conversationId] = ConversationSummary(
        conversationId: conversationId,
        lastBody: map['body'] as String,
        lastAt: DateTime.parse(map['created_at'] as String).toUtc(),
        title: room?.name,
        memberCount: room?.memberCount,
        unreadCount: room?.unreadCount ?? 0,
      );
    }

    final roomRows = await db.query(
      'chat_rooms',
      orderBy: 'COALESCE(last_message_at, updated_at) DESC',
    );
    for (final row in roomRows) {
      final room = ChatRoom.fromMap(Map<String, Object?>.from(row));
      summaries.putIfAbsent(
        room.conversationId,
        () => ConversationSummary(
          conversationId: room.conversationId,
          lastBody: room.lastMessagePreview ?? '',
          lastAt: room.lastMessageAt ?? room.updatedAt,
          title: room.name,
          memberCount: room.memberCount,
          unreadCount: room.unreadCount,
        ),
      );
    }

    final values = summaries.values.toList(growable: false)
      ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return values;
  }

  @override
  Future<List<ChatRoom>> listRooms() async {
    final db = await _encryptedDatabase.open();
    final rows = await db.query(
      'chat_rooms',
      orderBy: 'COALESCE(last_message_at, updated_at) DESC',
    );
    return rows
        .map((row) => ChatRoom.fromMap(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<ChatRoom?> readRoom(String roomId) async {
    final db = await _encryptedDatabase.open();
    final rows = await db.query(
      'chat_rooms',
      where: 'id = ?',
      whereArgs: [roomId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ChatRoom.fromMap(Map<String, Object?>.from(rows.first));
  }

  @override
  Future<void> replaceRooms(List<ChatRoom> rooms) async {
    final db = await _encryptedDatabase.open();
    await db.transaction((txn) async {
      await txn.delete('chat_rooms');
      for (final room in rooms) {
        await txn.insert(
          'chat_rooms',
          room.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> updateRoomUnreadCount({
    required String roomId,
    required int unreadCount,
  }) async {
    final db = await _encryptedDatabase.open();
    await db.update(
      'chat_rooms',
      {'unread_count': unreadCount},
      where: 'id = ?',
      whereArgs: [roomId],
    );
  }

  @override
  Future<ConversationNote?> readNote(String conversationId) async {
    final db = await _encryptedDatabase.open();
    final rows = await db.query(
      'conversation_notes',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ConversationNote.fromMap(Map<String, Object?>.from(rows.first));
  }

  @override
  Future<void> saveNote(ConversationNote note) async {
    final db = await _encryptedDatabase.open();
    await db.insert(
      'conversation_notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<TodoItem>> listTodos(String conversationId) async {
    final db = await _encryptedDatabase.open();
    final rows = await db.query(
      'todo_items',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'sort_order ASC',
    );
    return rows
        .map((row) => TodoItem.fromMap(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<void> upsertTodo(TodoItem todo) async {
    final db = await _encryptedDatabase.open();
    await db.insert(
      'todo_items',
      todo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteTodo(String todoId) async {
    final db = await _encryptedDatabase.open();
    await db.delete('todo_items', where: 'id = ?', whereArgs: [todoId]);
  }

  @override
  Future<void> replaceTodos(
    String conversationId,
    List<TodoItem> todos,
  ) async {
    final db = await _encryptedDatabase.open();
    await db.transaction((txn) async {
      await txn.delete(
        'todo_items',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );
      for (final todo in todos) {
        await txn.insert('todo_items', todo.toMap());
      }
    });
  }

  String _generateMessageId() {
    final random = Random.secure().nextInt(1000000);
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'm_${micros}_$random';
  }
}

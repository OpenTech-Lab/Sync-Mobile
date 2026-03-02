import 'dart:math';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/local_chat_message.dart';
import 'encrypted_database.dart';

class ConversationSummary {
  const ConversationSummary({
    required this.conversationId,
    required this.lastBody,
    required this.lastAt,
  });
  final String conversationId;
  final String lastBody;
  final DateTime lastAt;
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

  Future<void> upsertMessages(List<LocalChatMessage> messages);

  Future<List<LocalChatMessage>> listAllMessages();

  Future<void> replaceAllMessages(List<LocalChatMessage> messages);

  Future<void> clearConversation(String conversationId);

  Future<List<ConversationSummary>> listConversations();
}

// ── In-memory fallback for Flutter Web (sqflite_sqlcipher is native-only) ───
class InMemoryChatRepository implements ChatRepository {
  final _store = <String, List<LocalChatMessage>>{};

  @override
  Future<List<LocalChatMessage>> listMessages({
    required String conversationId,
    int limit = 100,
  }) async {
    final msgs = (_store[conversationId] ?? []).reversed.take(limit).toList();
    return msgs;
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
    final summaries = <ConversationSummary>[];
    for (final entry in _store.entries) {
      if (entry.value.isEmpty) continue;
      final sorted = [...entry.value]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      summaries.add(ConversationSummary(
        conversationId: entry.key,
        lastBody: sorted.first.body,
        lastAt: sorted.first.createdAt,
      ));
    }
    summaries.sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return summaries;
  }
}

class LocalChatRepository implements ChatRepository {
  LocalChatRepository([EncryptedDatabase? encryptedDatabase])
      : _encryptedDatabase = encryptedDatabase ?? EncryptedDatabase();

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

    final summaries = <ConversationSummary>[];
    final seenConversationIds = <String>{};

    for (final row in rows) {
      final map = Map<String, Object?>.from(row);
      final conversationId = map['conversation_id'] as String;
      if (seenConversationIds.contains(conversationId)) {
        continue;
      }

      seenConversationIds.add(conversationId);
      summaries.add(
        ConversationSummary(
          conversationId: conversationId,
          lastBody: map['body'] as String,
          lastAt: DateTime.parse(map['created_at'] as String).toUtc(),
        ),
      );
    }

    return summaries;
  }

  String _generateMessageId() {
    final random = Random.secure().nextInt(1000000);
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'm_${micros}_$random';
  }
}

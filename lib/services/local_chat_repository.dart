import 'dart:math';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/local_chat_message.dart';
import 'encrypted_database.dart';

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

  String _generateMessageId() {
    final random = Random.secure().nextInt(1000000);
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'm_${micros}_$random';
  }
}

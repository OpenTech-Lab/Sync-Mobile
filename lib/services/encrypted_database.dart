import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'server_scope.dart';

class EncryptedDatabase {
  EncryptedDatabase({
    required String serverUrl,
    FlutterSecureStorage? secureStorage,
  }) : _serverUrl = serverUrl,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _legacyDatabaseName = 'sync_local_chat.db';
  static const _databaseVersion = 1;
  static const _legacyDatabaseKeyStorageKey = 'local_chat_db_key';

  final String _serverUrl;
  final FlutterSecureStorage _secureStorage;
  Database? _database;

  String get _databaseName =>
      'sync_local_chat_${serverDatabaseSlug(_serverUrl)}.db';

  String get _databaseKeyStorageKey =>
      scopedStorageKey(_legacyDatabaseKeyStorageKey, _serverUrl);

  Future<Database> open() async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = path.join(documentsDirectory.path, _databaseName);
    await _migrateLegacyDatabaseIfNeeded(
      documentsDirectory: documentsDirectory.path,
      databasePath: databasePath,
    );
    final encryptionKey = await _readOrCreateEncryptionKey();

    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      password: encryptionKey,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE local_messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            body TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_local_messages_conversation_created_at ON local_messages(conversation_id, created_at DESC)',
        );
      },
    );

    return _database!;
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;
  }

  Future<String> _readOrCreateEncryptionKey() async {
    final existing = await _secureStorage.read(key: _databaseKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final generated = List.generate(
      64,
      (_) => chars[random.nextInt(chars.length)],
    ).join();

    await _secureStorage.write(key: _databaseKeyStorageKey, value: generated);
    return generated;
  }

  Future<void> _migrateLegacyDatabaseIfNeeded({
    required String documentsDirectory,
    required String databasePath,
  }) async {
    final scopedFile = File(databasePath);
    if (await scopedFile.exists()) {
      return;
    }

    final legacyPath = path.join(documentsDirectory, _legacyDatabaseName);
    final legacyFile = File(legacyPath);
    if (!await legacyFile.exists()) {
      return;
    }

    await legacyFile.rename(databasePath);

    final scopedKey = await _secureStorage.read(key: _databaseKeyStorageKey);
    if (scopedKey != null && scopedKey.isNotEmpty) {
      return;
    }

    final legacyKey = await _secureStorage.read(
      key: _legacyDatabaseKeyStorageKey,
    );
    if (legacyKey == null || legacyKey.isEmpty) {
      return;
    }

    await _secureStorage.write(key: _databaseKeyStorageKey, value: legacyKey);
    await _secureStorage.delete(key: _legacyDatabaseKeyStorageKey);
  }
}

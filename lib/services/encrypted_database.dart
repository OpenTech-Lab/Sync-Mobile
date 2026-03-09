import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'server_scope.dart';

@visibleForTesting
String? selectStoredEncryptionKey({
  required bool scopedFileExists,
  required String? scopedKey,
  required String? legacyKey,
}) {
  final normalizedScopedKey = scopedKey?.trim();
  if (normalizedScopedKey != null && normalizedScopedKey.isNotEmpty) {
    return normalizedScopedKey;
  }

  final normalizedLegacyKey = legacyKey?.trim();
  if (scopedFileExists &&
      normalizedLegacyKey != null &&
      normalizedLegacyKey.isNotEmpty) {
    return normalizedLegacyKey;
  }

  return null;
}

@visibleForTesting
bool isRecoverableDatabaseOpenError(Object error) {
  if (error is DatabaseException && error.isOpenFailedError()) {
    return true;
  }
  final message = error.toString().toLowerCase();
  return message.contains('file is not a database') ||
      message.contains('sqlitenotadatabaseexception') ||
      message.contains('hmac check failed') ||
      message.contains('cipher_migrate') ||
      message.contains('error decrypting page') ||
      message.contains('bad decrypt');
}

class EncryptedDatabase {
  EncryptedDatabase({
    required String serverUrl,
    FlutterSecureStorage? secureStorage,
  }) : _serverUrl = serverUrl,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _legacyDatabaseName = 'sync_local_chat.db';
  static const _databaseVersion = 2;
  static const _legacyDatabaseKeyStorageKey = 'local_chat_db_key';

  final String _serverUrl;
  final FlutterSecureStorage _secureStorage;
  Database? _database;
  Future<Database>? _openingDatabase;

  String get _databaseName =>
      'sync_local_chat_${serverDatabaseSlug(_serverUrl)}.db';

  String get _databaseKeyStorageKey =>
      scopedStorageKey(_legacyDatabaseKeyStorageKey, _serverUrl);

  Future<Database> open() async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    final openingDatabase = _openingDatabase;
    if (openingDatabase != null) {
      return openingDatabase;
    }

    final future = _openInternal();
    _openingDatabase = future;
    try {
      return await future;
    } finally {
      if (identical(_openingDatabase, future)) {
        _openingDatabase = null;
      }
    }
  }

  Future<Database> _openInternal() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = path.join(documentsDirectory.path, _databaseName);
    await _migrateLegacyDatabaseIfNeeded(
      documentsDirectory: documentsDirectory.path,
      databasePath: databasePath,
    );
    final encryptionKey = await _readOrCreateEncryptionKey(
      documentsDirectory: documentsDirectory.path,
      databasePath: databasePath,
    );

    try {
      _database = await _openDatabase(databasePath, encryptionKey);
    } catch (error) {
      if (!_isRecoverableOpenError(error)) {
        rethrow;
      }
      debugPrint(
        'EncryptedDatabase: resetting unreadable local cache at $databasePath',
      );
      _database = null;
      await _resetUnreadableDatabase(databasePath);
      _database = await _openDatabase(databasePath, encryptionKey);
    }

    return _database!;
  }

  Future<void> close() async {
    await _openingDatabase;
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;
  }

  Future<Database> _openDatabase(String databasePath, String encryptionKey) {
    return openDatabase(
      databasePath,
      version: _databaseVersion,
      password: encryptionKey,
      singleInstance: false,
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
        await _createRoomsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createRoomsTable(db);
        }
      },
    );
  }

  Future<String> _readOrCreateEncryptionKey({
    required String documentsDirectory,
    required String databasePath,
  }) async {
    final scopedFileExists = await File(databasePath).exists();
    final scopedKey = await _secureStorage.read(key: _databaseKeyStorageKey);
    final legacyKey = await _secureStorage.read(
      key: _legacyDatabaseKeyStorageKey,
    );
    final storedKey = selectStoredEncryptionKey(
      scopedFileExists: scopedFileExists,
      scopedKey: scopedKey,
      legacyKey: legacyKey,
    );
    if (storedKey != null) {
      if (scopedKey == null || scopedKey.trim().isEmpty) {
        await _secureStorage.write(
          key: _databaseKeyStorageKey,
          value: storedKey,
        );
      }
      return storedKey;
    }

    final legacyPath = path.join(documentsDirectory, _legacyDatabaseName);
    if (legacyKey != null &&
        legacyKey.isNotEmpty &&
        await File(legacyPath).exists()) {
      await _secureStorage.write(key: _databaseKeyStorageKey, value: legacyKey);
      return legacyKey;
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

    try {
      await legacyFile.rename(databasePath);
    } on FileSystemException {
      if (!await scopedFile.exists()) {
        rethrow;
      }
    }

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

  bool _isRecoverableOpenError(Object error) {
    return isRecoverableDatabaseOpenError(error);
  }

  Future<void> _resetUnreadableDatabase(String databasePath) async {
    Object? deleteError;
    try {
      await deleteDatabase(databasePath);
    } catch (error) {
      deleteError = error;
    }

    await _deleteDatabaseFiles(databasePath);

    if (await File(databasePath).exists()) {
      throw StateError(
        'Failed to remove unreadable local cache at $databasePath'
        '${deleteError == null ? '' : ': $deleteError'}',
      );
    }
  }

  Future<void> _deleteDatabaseFiles(String databasePath) async {
    const suffixes = <String>['', '-wal', '-shm', '-journal'];
    for (final suffix in suffixes) {
      final file = File('$databasePath$suffix');
      if (!await file.exists()) {
        continue;
      }
      try {
        await file.delete();
      } on FileSystemException {
        if (await file.exists()) {
          rethrow;
        }
      }
    }
  }

  Future<void> _createRoomsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_rooms (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        member_count INTEGER NOT NULL DEFAULT 0,
        unread_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_message_preview TEXT,
        last_message_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_rooms_updated_at ON chat_rooms(updated_at DESC)',
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/local_chat_message.dart';
import 'backup_crypto_service.dart';

class EncryptedBackupService {
  EncryptedBackupService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _backupKeyStorageKey = 'local_backup_encryption_key';
  static const _backupFileName = 'sync_local_backup.enc';

  final FlutterSecureStorage _storage;
  final _crypto = BackupCryptoService();

  Future<String> backupMessages(List<LocalChatMessage> messages) async {
    final payload = jsonEncode({
      'version': 1,
      'messages': messages.map((message) => message.toMap()).toList(),
    });

    final secretKey = await _readOrCreateSecretKey();
    final nonce = _randomBytes(12);
    final blob = await _crypto.encryptToJson(
      clearBytes: utf8.encode(payload),
      secretKey: secretKey,
      nonce: nonce,
    );

    final file = await _backupFile();
    await file.writeAsString(blob, flush: true);
    return file.path;
  }

  Future<List<LocalChatMessage>> restoreMessages() async {
    final file = await _backupFile();
    if (!await file.exists()) {
      return const [];
    }

    final raw = await file.readAsString();
    final secretKey = await _readOrCreateSecretKey();

    final clearBytes = await _crypto.decryptFromJson(
      payload: raw,
      secretKey: secretKey,
    );
    final payload = jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;

    final messages = payload['messages'] as List<dynamic>? ?? const [];
    return messages
        .map((item) => LocalChatMessage.fromMap(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }

  Future<bool> hasBackup() async {
    final file = await _backupFile();
    return file.exists();
  }

  Future<File> _backupFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File(path.join(docs.path, _backupFileName));
  }

  Future<SecretKey> _readOrCreateSecretKey() async {
    final existing = await _storage.read(key: _backupKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return SecretKey(base64Decode(existing));
    }

    final keyBytes = _randomBytes(32);
    await _storage.write(
      key: _backupKeyStorageKey,
      value: base64Encode(keyBytes),
    );
    return SecretKey(keyBytes);
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}

import 'package:shared_preferences/shared_preferences.dart';

import 'server_scope.dart';

class BackupPreferences {
  static const _enabledPrefix = 'backup_enabled';
  static const _lastBackupAtPrefix = 'backup_last_backup_at';
  static const _lastBackedMessageCountPrefix = 'backup_last_message_count';
  static const _autoBackupMessageThresholdPrefix = 'backup_auto_threshold';
  static const _chatClearedAtPrefix = 'chat_cleared_at';
  static const int defaultAutoBackupMessageThreshold = 20;

  String _enabledKey(String serverUrl) =>
      scopedStorageKey(_enabledPrefix, serverUrl);

  String _lastBackupAtKey(String serverUrl) =>
      scopedStorageKey(_lastBackupAtPrefix, serverUrl);

  String _lastBackedMessageCountKey(String serverUrl) =>
      scopedStorageKey(_lastBackedMessageCountPrefix, serverUrl);

  String _autoBackupMessageThresholdKey(String serverUrl) =>
      scopedStorageKey(_autoBackupMessageThresholdPrefix, serverUrl);

  String _chatClearedAtKey(String serverUrl) =>
      scopedStorageKey(_chatClearedAtPrefix, serverUrl);

  Future<bool> readEnabled(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    return await _readBool(
          prefs: prefs,
          scopedKey: _enabledKey(serverUrl),
          legacyKey: _enabledPrefix,
        ) ??
        false;
  }

  Future<void> writeEnabled(String serverUrl, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey(serverUrl), enabled);
    await prefs.remove(_enabledPrefix);
  }

  Future<DateTime?> readLastBackupAt(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await _readString(
      prefs: prefs,
      scopedKey: _lastBackupAtKey(serverUrl),
      legacyKey: _lastBackupAtPrefix,
    );
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<int> readLastBackedMessageCount(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    return await _readInt(
          prefs: prefs,
          scopedKey: _lastBackedMessageCountKey(serverUrl),
          legacyKey: _lastBackedMessageCountPrefix,
        ) ??
        0;
  }

  Future<void> writeLastBackupMetadata({
    required String serverUrl,
    required DateTime backedAt,
    required int messageCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastBackupAtKey(serverUrl),
      backedAt.toUtc().toIso8601String(),
    );
    await prefs.setInt(_lastBackedMessageCountKey(serverUrl), messageCount);
    await prefs.remove(_lastBackupAtPrefix);
    await prefs.remove(_lastBackedMessageCountPrefix);
  }

  Future<void> clearLastBackupMetadata(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastBackupAtKey(serverUrl));
    await prefs.remove(_lastBackedMessageCountKey(serverUrl));
    await prefs.remove(_lastBackupAtPrefix);
    await prefs.remove(_lastBackedMessageCountPrefix);
  }

  Future<int> readAutoBackupMessageThreshold(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final value = await _readInt(
      prefs: prefs,
      scopedKey: _autoBackupMessageThresholdKey(serverUrl),
      legacyKey: _autoBackupMessageThresholdPrefix,
    );
    if (value == null) {
      return defaultAutoBackupMessageThreshold;
    }
    return value.clamp(1, 1000);
  }

  Future<void> writeAutoBackupMessageThreshold(String serverUrl, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _autoBackupMessageThresholdKey(serverUrl),
      value.clamp(1, 1000),
    );
    await prefs.remove(_autoBackupMessageThresholdPrefix);
  }

  Future<DateTime?> readChatClearedAt(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await _readString(
      prefs: prefs,
      scopedKey: _chatClearedAtKey(serverUrl),
      legacyKey: _chatClearedAtPrefix,
    );
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> writeChatClearedAt(String serverUrl, DateTime clearedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chatClearedAtKey(serverUrl),
      clearedAt.toUtc().toIso8601String(),
    );
    await prefs.remove(_chatClearedAtPrefix);
  }

  Future<String?> _readString({
    required SharedPreferences prefs,
    required String scopedKey,
    required String legacyKey,
  }) async {
    final scoped = prefs.getString(scopedKey);
    if (scoped != null && scoped.isNotEmpty) {
      return scoped;
    }
    final legacy = prefs.getString(legacyKey);
    if (legacy == null || legacy.isEmpty) {
      return null;
    }
    await prefs.setString(scopedKey, legacy);
    await prefs.remove(legacyKey);
    return legacy;
  }

  Future<int?> _readInt({
    required SharedPreferences prefs,
    required String scopedKey,
    required String legacyKey,
  }) async {
    final scoped = prefs.getInt(scopedKey);
    if (scoped != null) {
      return scoped;
    }
    final legacy = prefs.getInt(legacyKey);
    if (legacy == null) {
      return null;
    }
    await prefs.setInt(scopedKey, legacy);
    await prefs.remove(legacyKey);
    return legacy;
  }

  Future<bool?> _readBool({
    required SharedPreferences prefs,
    required String scopedKey,
    required String legacyKey,
  }) async {
    final scoped = prefs.getBool(scopedKey);
    if (scoped != null) {
      return scoped;
    }
    final legacy = prefs.getBool(legacyKey);
    if (legacy == null) {
      return null;
    }
    await prefs.setBool(scopedKey, legacy);
    await prefs.remove(legacyKey);
    return legacy;
  }
}

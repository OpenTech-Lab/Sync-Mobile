import 'package:shared_preferences/shared_preferences.dart';

class BackupPreferences {
  static const _enabledKey = 'backup_enabled';
  static const _lastBackupAtKey = 'backup_last_backup_at';
  static const _lastBackedMessageCountKey = 'backup_last_message_count';
  static const _autoBackupMessageThresholdKey = 'backup_auto_threshold';
  static const int defaultAutoBackupMessageThreshold = 20;

  Future<bool> readEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> writeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<DateTime?> readLastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastBackupAtKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<int> readLastBackedMessageCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastBackedMessageCountKey) ?? 0;
  }

  Future<void> writeLastBackupMetadata({
    required DateTime backedAt,
    required int messageCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupAtKey, backedAt.toUtc().toIso8601String());
    await prefs.setInt(_lastBackedMessageCountKey, messageCount);
  }

  Future<void> clearLastBackupMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastBackupAtKey);
    await prefs.remove(_lastBackedMessageCountKey);
  }

  Future<int> readAutoBackupMessageThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_autoBackupMessageThresholdKey);
    if (value == null) {
      return defaultAutoBackupMessageThreshold;
    }
    return value.clamp(1, 1000);
  }

  Future<void> writeAutoBackupMessageThreshold(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoBackupMessageThresholdKey, value.clamp(1, 1000));
  }
}

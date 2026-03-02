import 'package:shared_preferences/shared_preferences.dart';

class BackupPreferences {
  static const _enabledKey = 'backup_enabled';

  Future<bool> readEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> writeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }
}

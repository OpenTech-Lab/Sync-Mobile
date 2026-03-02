import 'package:shared_preferences/shared_preferences.dart';

class ServerPreferences {
  static const _serverUrlKey = 'server_url';

  Future<String?> readServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  Future<void> writeServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, _normalizeBaseUrl(url));
  }

  Future<void> clearServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverUrlKey);
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}

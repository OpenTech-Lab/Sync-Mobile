import 'package:shared_preferences/shared_preferences.dart';

class ServerPreferences {
  static const _serverUrlKey = 'server_url';
  static const _savedEmailPrefix = 'saved_email_';

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

  String _emailKey(String serverUrl) =>
      '$_savedEmailPrefix${Uri.tryParse(serverUrl)?.host ?? serverUrl}';

  Future<String?> readSavedEmail(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey(serverUrl));
  }

  Future<void> writeSavedEmail(String serverUrl, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey(serverUrl), email);
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}

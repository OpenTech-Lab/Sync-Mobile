import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'server_health_service.dart';

class CachedPlanetInfo {
  const CachedPlanetInfo({
    required this.instanceName,
    required this.instanceDescription,
    required this.instanceImageUrl,
    required this.instanceDomain,
    required this.countryCode,
    required this.countryName,
    required this.healthStatus,
    required this.latencyMs,
    required this.checkedAt,
  });

  final String? instanceName;
  final String? instanceDescription;
  final String? instanceImageUrl;
  final String? instanceDomain;
  final String? countryCode;
  final String? countryName;
  final String healthStatus;
  final int latencyMs;
  final DateTime checkedAt;
}

class ServerPreferences {
  static const _serverUrlKey = 'server_url';
  static const _savedEmailPrefix = 'saved_email_';
  static const _planetInfoPrefix = 'planet_info_';

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

  String _planetInfoKey(String serverUrl) =>
      '$_planetInfoPrefix${_normalizeBaseUrl(serverUrl).toLowerCase()}';

  Future<CachedPlanetInfo?> readPlanetInfo(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_planetInfoKey(serverUrl));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final checkedAtMs = decoded['checked_at_ms'];
      return CachedPlanetInfo(
        instanceName: decoded['instance_name'] as String?,
        instanceDescription: decoded['instance_description'] as String?,
        instanceImageUrl: decoded['instance_image_url'] as String?,
        instanceDomain: decoded['instance_domain'] as String?,
        countryCode: decoded['country_code'] as String?,
        countryName: decoded['country_name'] as String?,
        healthStatus:
            (decoded['health_status'] as String?)?.trim().isNotEmpty == true
            ? (decoded['health_status'] as String).trim()
            : 'ok',
        latencyMs: (decoded['latency_ms'] as int?) ?? 0,
        checkedAt: checkedAtMs is int
            ? DateTime.fromMillisecondsSinceEpoch(checkedAtMs)
            : DateTime.fromMillisecondsSinceEpoch(0),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writePlanetInfo({
    required String serverUrl,
    required PlanetInfo planetInfo,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'instance_name': planetInfo.instanceName,
      'instance_description': planetInfo.instanceDescription,
      'instance_image_url': planetInfo.instanceImageUrl,
      'instance_domain': planetInfo.instanceDomain,
      'country_code': planetInfo.countryCode,
      'country_name': planetInfo.countryName,
      'health_status': planetInfo.healthStatus,
      'latency_ms': planetInfo.latencyMs,
      'checked_at_ms': planetInfo.checkedAt.millisecondsSinceEpoch,
    };
    await prefs.setString(_planetInfoKey(serverUrl), jsonEncode(payload));
  }

  Future<void> clearPlanetInfo(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_planetInfoKey(serverUrl));
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}

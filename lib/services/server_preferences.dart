import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'server_scope.dart';
import 'server_health_service.dart';

class CachedPlanetInfo {
  const CachedPlanetInfo({
    required this.instanceName,
    required this.instanceDescription,
    required this.instanceImageUrl,
    required this.memberCount,
    required this.linkedPlanets,
    required this.instanceDomain,
    required this.countryCode,
    required this.countryName,
    required this.serverCreatedAt,
    required this.healthStatus,
    required this.latencyMs,
    required this.checkedAt,
    required this.registrationRequiresApproval,
  });

  final String? instanceName;
  final String? instanceDescription;
  final String? instanceImageUrl;
  final int? memberCount;
  final List<String> linkedPlanets;
  final String? instanceDomain;
  final String? countryCode;
  final String? countryName;
  final DateTime? serverCreatedAt;
  final String healthStatus;
  final int latencyMs;
  final DateTime checkedAt;
  final bool registrationRequiresApproval;
}

class ServerPreferences {
  static const _serverUrlKey = 'server_url';
  static const _savedUserIdPrefix = 'saved_user_id_';
  static const _planetInfoPrefix = 'planet_info_';

  Future<String?> readServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  Future<void> writeServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, normalizeServerUrl(url));
  }

  Future<void> clearServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverUrlKey);
  }

  String _userIdKey(String serverUrl) =>
      scopedStorageKey(_savedUserIdPrefix, serverUrl);

  Future<String?> readSavedUserId(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey(serverUrl));
  }

  Future<void> writeSavedUserId(String serverUrl, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey(serverUrl), userId);
  }

  String _planetInfoKey(String serverUrl) =>
      scopedStorageKey(_planetInfoPrefix, serverUrl);

  String _legacyPlanetInfoKey(String serverUrl) =>
      '$_planetInfoPrefix${normalizeServerUrl(serverUrl).toLowerCase()}';

  Future<CachedPlanetInfo?> readPlanetInfo(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_planetInfoKey(serverUrl));
    if ((raw == null || raw.trim().isEmpty)) {
      final legacyKey = _legacyPlanetInfoKey(serverUrl);
      final legacyRaw = prefs.getString(legacyKey);
      if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
        raw = legacyRaw;
        await prefs.setString(_planetInfoKey(serverUrl), legacyRaw);
        await prefs.remove(legacyKey);
      }
    }
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final checkedAtMs = decoded['checked_at_ms'];
      final rawServerCreatedAt = decoded['server_created_at'];
      return CachedPlanetInfo(
        instanceName: decoded['instance_name'] as String?,
        instanceDescription: decoded['instance_description'] as String?,
        instanceImageUrl: decoded['instance_image_url'] as String?,
        memberCount: decoded['member_count'] as int?,
        linkedPlanets:
            ((decoded['linked_planets'] as List<dynamic>?) ?? const [])
                .whereType<String>()
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false),
        instanceDomain: decoded['instance_domain'] as String?,
        countryCode: decoded['country_code'] as String?,
        countryName: decoded['country_name'] as String?,
        serverCreatedAt: rawServerCreatedAt is String
            ? DateTime.tryParse(rawServerCreatedAt)?.toUtc()
            : null,
        healthStatus:
            (decoded['health_status'] as String?)?.trim().isNotEmpty == true
            ? (decoded['health_status'] as String).trim()
            : 'ok',
        latencyMs: (decoded['latency_ms'] as int?) ?? 0,
        checkedAt: checkedAtMs is int
            ? DateTime.fromMillisecondsSinceEpoch(checkedAtMs)
            : DateTime.fromMillisecondsSinceEpoch(0),
        registrationRequiresApproval:
            (decoded['registration_requires_approval'] as bool?) ?? false,
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
      'member_count': planetInfo.memberCount,
      'linked_planets': planetInfo.linkedPlanets,
      'instance_domain': planetInfo.instanceDomain,
      'country_code': planetInfo.countryCode,
      'country_name': planetInfo.countryName,
      'server_created_at': planetInfo.serverCreatedAt?.toIso8601String(),
      'health_status': planetInfo.healthStatus,
      'latency_ms': planetInfo.latencyMs,
      'checked_at_ms': planetInfo.checkedAt.millisecondsSinceEpoch,
      'registration_requires_approval':
          planetInfo.registrationRequiresApproval,
    };
    await prefs.setString(_planetInfoKey(serverUrl), jsonEncode(payload));
  }

  Future<void> clearPlanetInfo(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_planetInfoKey(serverUrl));
    await prefs.remove(_legacyPlanetInfoKey(serverUrl));
  }
}

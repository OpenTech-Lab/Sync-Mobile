import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/planet_page_data.dart';
import 'server_scope.dart';

class PlanetPageCacheService {
  static const _cachePrefix = 'planet_page_cache_v1';

  String _cacheKey(String serverUrl) =>
      scopedStorageKey(_cachePrefix, serverUrl);

  Future<PlanetPageData?> read(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(serverUrl));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return PlanetPageData.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String serverUrl, PlanetPageData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey(serverUrl), jsonEncode(data.toMap()));
  }

  Future<void> clear(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey(serverUrl));
  }
}

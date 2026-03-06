import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sticker.dart';
import 'server_scope.dart';

class StickerCacheService {
  static const _cachePrefix = 'sticker_cache_v1';

  String _cacheKey(String serverUrl) => scopedStorageKey(_cachePrefix, serverUrl);

  Future<List<Sticker>> read(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_cacheKey(serverUrl));
    if ((raw == null || raw.isEmpty)) {
      final legacy = prefs.getString(_cachePrefix);
      if (legacy != null && legacy.isNotEmpty) {
        raw = legacy;
        await prefs.setString(_cacheKey(serverUrl), legacy);
        await prefs.remove(_cachePrefix);
      }
    }
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => Sticker.fromMap(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> write(String serverUrl, List<Sticker> stickers) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      stickers.map((sticker) => sticker.toMap()).toList(),
    );
    await prefs.setString(_cacheKey(serverUrl), payload);
    await prefs.remove(_cachePrefix);
  }
}

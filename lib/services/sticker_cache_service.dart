import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sticker.dart';

class StickerCacheService {
  static const _cacheKey = 'sticker_cache_v1';

  Future<List<Sticker>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => Sticker.fromMap(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> write(List<Sticker> stickers) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      stickers.map((sticker) => sticker.toMap()).toList(),
    );
    await prefs.setString(_cacheKey, payload);
  }
}

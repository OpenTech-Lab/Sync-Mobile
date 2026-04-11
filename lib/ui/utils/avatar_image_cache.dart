import 'dart:convert';

import 'package:flutter/painting.dart';

/// Caches decoded [MemoryImage] instances keyed by userId.
///
/// Reuses the same [MemoryImage] when the base64 data hasn't changed,
/// which lets Flutter's image cache serve the texture without re-decoding.
/// The entry is replaced only when a genuinely different avatar arrives.
class AvatarImageCache {
  AvatarImageCache._();

  static final Map<String, (String base64, MemoryImage image)> _cache = {};

  /// Returns a cached [MemoryImage] for [userId] if [base64] is unchanged,
  /// otherwise decodes and caches a new one. Returns `null` if [base64] is null.
  static MemoryImage? resolve(String userId, String? base64) {
    if (base64 == null || base64.isEmpty) {
      _cache.remove(userId);
      return null;
    }
    final cached = _cache[userId];
    if (cached != null && cached.$1 == base64) return cached.$2;
    final image = MemoryImage(base64Decode(base64));
    _cache[userId] = (base64, image);
    return image;
  }
}

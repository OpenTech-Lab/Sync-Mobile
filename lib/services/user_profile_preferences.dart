import 'package:shared_preferences/shared_preferences.dart';

class UserProfilePreferences {
  String _displayNameKey(String userId) => 'profile_display_name_$userId';
  String _avatarKey(String userId) => 'profile_avatar_base64_$userId';
  String _descriptionKey(String userId) => 'profile_description_$userId';
  String _friendAddedAtKey(String userId) => 'friend_added_at_$userId';
  static const String _friendIdsKey = 'friend_ids';

  Future<String?> readDisplayName(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_displayNameKey(userId));
  }

  Future<void> writeDisplayName(String userId, String? displayName) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = displayName?.trim();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_displayNameKey(userId));
      return;
    }
    await prefs.setString(_displayNameKey(userId), normalized);
  }

  Future<String?> readAvatarBase64(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarKey(userId));
  }

  Future<void> writeAvatarBase64(String userId, String? avatarBase64) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = avatarBase64?.trim();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_avatarKey(userId));
      return;
    }
    await prefs.setString(_avatarKey(userId), normalized);
  }

  Future<String?> readDescription(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_descriptionKey(userId));
  }

  Future<void> writeDescription(String userId, String? description) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = description?.trim();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_descriptionKey(userId));
      return;
    }
    await prefs.setString(_descriptionKey(userId), normalized);
  }

  Future<List<String>> readFriendIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_friendIdsKey) ?? const <String>[];
    return raw
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<DateTime?> readFriendAddedAt(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_friendAddedAtKey(userId.trim()));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw.trim())?.toLocal();
  }

  Future<void> addFriendId(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_friendIdsKey) ?? const <String>[];
    final existingNormalized = existing
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final next = {...existingNormalized, normalized}.toList(growable: false);
    await prefs.setStringList(_friendIdsKey, next);
    if (!existingNormalized.contains(normalized)) {
      await prefs.setString(
        _friendAddedAtKey(normalized),
        DateTime.now().toUtc().toIso8601String(),
      );
    }
  }

  Future<void> removeFriendId(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_friendIdsKey) ?? const <String>[];
    final next = existing
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != normalized)
        .toSet()
        .toList(growable: false);
    await prefs.setStringList(_friendIdsKey, next);
    await prefs.remove(_friendAddedAtKey(normalized));
  }
}

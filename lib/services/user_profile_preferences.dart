import 'package:shared_preferences/shared_preferences.dart';

class UserProfilePreferences {
  String _displayNameKey(String userId) => 'profile_display_name_$userId';
  String _avatarKey(String userId) => 'profile_avatar_base64_$userId';

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
}

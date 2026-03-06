import 'package:shared_preferences/shared_preferences.dart';

import 'server_scope.dart';

class UserProfilePreferences {
  static const String _displayNamePrefix = 'profile_display_name';
  static const String _avatarPrefix = 'profile_avatar_base64';
  static const String _descriptionPrefix = 'profile_description';
  static const String _friendAddedAtPrefix = 'friend_added_at';
  static const String _friendIdsPrefix = 'friend_ids';

  String _displayNameKey(String serverUrl, String userId) =>
      scopedStorageKey(_displayNamePrefix, serverUrl, suffix: userId);

  String _avatarKey(String serverUrl, String userId) =>
      scopedStorageKey(_avatarPrefix, serverUrl, suffix: userId);

  String _descriptionKey(String serverUrl, String userId) =>
      scopedStorageKey(_descriptionPrefix, serverUrl, suffix: userId);

  String _friendAddedAtKey(String serverUrl, String userId) =>
      scopedStorageKey(_friendAddedAtPrefix, serverUrl, suffix: userId);

  String _friendIdsKey(String serverUrl) =>
      scopedStorageKey(_friendIdsPrefix, serverUrl);

  String _legacyDisplayNameKey(String userId) => 'profile_display_name_$userId';
  String _legacyAvatarKey(String userId) => 'profile_avatar_base64_$userId';
  String _legacyDescriptionKey(String userId) => 'profile_description_$userId';
  String _legacyFriendAddedAtKey(String userId) => 'friend_added_at_$userId';
  static const String _legacyFriendIdsKey = 'friend_ids';

  Future<String?> readDisplayName(String serverUrl, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return _readScopedString(
      prefs: prefs,
      scopedKey: _displayNameKey(serverUrl, userId),
      legacyKey: _legacyDisplayNameKey(userId),
    );
  }

  Future<void> writeDisplayName(
    String serverUrl,
    String userId,
    String? displayName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = displayName?.trim();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_displayNameKey(serverUrl, userId));
      await prefs.remove(_legacyDisplayNameKey(userId));
      return;
    }
    await prefs.setString(_displayNameKey(serverUrl, userId), normalized);
    await prefs.remove(_legacyDisplayNameKey(userId));
  }

  Future<String?> readAvatarBase64(String serverUrl, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return _readScopedString(
      prefs: prefs,
      scopedKey: _avatarKey(serverUrl, userId),
      legacyKey: _legacyAvatarKey(userId),
    );
  }

  Future<void> writeAvatarBase64(
    String serverUrl,
    String userId,
    String? avatarBase64,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = avatarBase64?.trim();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_avatarKey(serverUrl, userId));
      await prefs.remove(_legacyAvatarKey(userId));
      return;
    }
    await prefs.setString(_avatarKey(serverUrl, userId), normalized);
    await prefs.remove(_legacyAvatarKey(userId));
  }

  Future<String?> readDescription(String serverUrl, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return _readScopedString(
      prefs: prefs,
      scopedKey: _descriptionKey(serverUrl, userId),
      legacyKey: _legacyDescriptionKey(userId),
    );
  }

  Future<void> writeDescription(
    String serverUrl,
    String userId,
    String? description,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = description?.trim();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_descriptionKey(serverUrl, userId));
      await prefs.remove(_legacyDescriptionKey(userId));
      return;
    }
    await prefs.setString(_descriptionKey(serverUrl, userId), normalized);
    await prefs.remove(_legacyDescriptionKey(userId));
  }

  Future<List<String>> readFriendIds(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getStringList(_friendIdsKey(serverUrl));
    if (raw == null) {
      final legacy = prefs.getStringList(_legacyFriendIdsKey);
      if (legacy != null) {
        raw = legacy;
        await prefs.setStringList(_friendIdsKey(serverUrl), legacy);
        await prefs.remove(_legacyFriendIdsKey);
      }
    }
    final normalized = (raw ?? const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isNotEmpty) {
      await prefs.setStringList(_friendIdsKey(serverUrl), normalized);
    }
    return normalized;
  }

  Future<DateTime?> readFriendAddedAt(String serverUrl, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedUserId = userId.trim();
    var raw = prefs.getString(_friendAddedAtKey(serverUrl, normalizedUserId));
    if (raw == null || raw.trim().isEmpty) {
      final legacyKey = _legacyFriendAddedAtKey(normalizedUserId);
      final legacyRaw = prefs.getString(legacyKey);
      if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
        raw = legacyRaw;
        await prefs.setString(
          _friendAddedAtKey(serverUrl, normalizedUserId),
          legacyRaw,
        );
        await prefs.remove(legacyKey);
      }
    }
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw.trim())?.toLocal();
  }

  Future<void> addFriendId(String serverUrl, String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final existing = await readFriendIds(serverUrl);
    final existingNormalized = existing
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final next = {...existingNormalized, normalized}.toList(growable: false);
    await prefs.setStringList(_friendIdsKey(serverUrl), next);
    await prefs.remove(_legacyFriendIdsKey);
    if (!existingNormalized.contains(normalized)) {
      await prefs.setString(
        _friendAddedAtKey(serverUrl, normalized),
        DateTime.now().toUtc().toIso8601String(),
      );
    }
    await prefs.remove(_legacyFriendAddedAtKey(normalized));
  }

  Future<void> removeFriendId(String serverUrl, String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final existing = await readFriendIds(serverUrl);
    final next = existing
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != normalized)
        .toSet()
        .toList(growable: false);
    await prefs.setStringList(_friendIdsKey(serverUrl), next);
    await prefs.remove(_friendAddedAtKey(serverUrl, normalized));
    await prefs.remove(_legacyFriendAddedAtKey(normalized));
  }

  Future<String?> _readScopedString({
    required SharedPreferences prefs,
    required String scopedKey,
    required String legacyKey,
  }) async {
    final scoped = prefs.getString(scopedKey);
    if (scoped != null && scoped.trim().isNotEmpty) {
      return scoped;
    }

    final legacy = prefs.getString(legacyKey);
    if (legacy == null || legacy.trim().isEmpty) {
      return null;
    }

    await prefs.setString(scopedKey, legacy);
    await prefs.remove(legacyKey);
    return legacy;
  }
}

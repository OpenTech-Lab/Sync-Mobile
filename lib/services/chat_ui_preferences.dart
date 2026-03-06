import 'package:shared_preferences/shared_preferences.dart';

import 'server_scope.dart';

class ChatUiPreferences {
  static const _typingStyleModeEnabledPrefix = 'chat_typing_style_mode_enabled';
  static const _typingStyleSpeedMsPrefix = 'chat_typing_style_speed_ms';
  static const _hiddenConversationIdsPrefix = 'chat_hidden_conversation_ids';
  static const defaultTypingStyleSpeedMs = 18;
  static const minTypingStyleSpeedMs = 8;
  static const maxTypingStyleSpeedMs = 60;

  String _typingStyleModeEnabledKey(String serverUrl) =>
      scopedStorageKey(_typingStyleModeEnabledPrefix, serverUrl);

  String _typingStyleSpeedMsKey(String serverUrl) =>
      scopedStorageKey(_typingStyleSpeedMsPrefix, serverUrl);

  String _hiddenConversationIdsKey(String serverUrl) =>
      scopedStorageKey(_hiddenConversationIdsPrefix, serverUrl);

  Future<bool> readTypingStyleModeEnabled(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final scoped = prefs.getBool(_typingStyleModeEnabledKey(serverUrl));
    if (scoped != null) {
      return scoped;
    }
    final legacy = prefs.getBool(_typingStyleModeEnabledPrefix);
    if (legacy != null) {
      await prefs.setBool(_typingStyleModeEnabledKey(serverUrl), legacy);
      await prefs.remove(_typingStyleModeEnabledPrefix);
      return legacy;
    }
    return false;
  }

  Future<void> writeTypingStyleModeEnabled(String serverUrl, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_typingStyleModeEnabledKey(serverUrl), enabled);
    await prefs.remove(_typingStyleModeEnabledPrefix);
  }

  Future<int> readTypingStyleSpeedMs(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getInt(_typingStyleSpeedMsKey(serverUrl)) ??
        prefs.getInt(_typingStyleSpeedMsPrefix) ??
        defaultTypingStyleSpeedMs;
    if (prefs.getInt(_typingStyleSpeedMsKey(serverUrl)) == null &&
        prefs.getInt(_typingStyleSpeedMsPrefix) != null) {
      await prefs.setInt(_typingStyleSpeedMsKey(serverUrl), raw);
      await prefs.remove(_typingStyleSpeedMsPrefix);
    }
    return raw.clamp(minTypingStyleSpeedMs, maxTypingStyleSpeedMs);
  }

  Future<void> writeTypingStyleSpeedMs(
    String serverUrl,
    int milliseconds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = milliseconds.clamp(
      minTypingStyleSpeedMs,
      maxTypingStyleSpeedMs,
    );
    await prefs.setInt(_typingStyleSpeedMsKey(serverUrl), clamped);
    await prefs.remove(_typingStyleSpeedMsPrefix);
  }

  Future<Set<String>> readHiddenConversationIds(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final list =
        prefs.getStringList(_hiddenConversationIdsKey(serverUrl)) ??
        prefs.getStringList(_hiddenConversationIdsPrefix) ??
        [];
    if (prefs.getStringList(_hiddenConversationIdsKey(serverUrl)) == null &&
        prefs.getStringList(_hiddenConversationIdsPrefix) != null) {
      await prefs.setStringList(_hiddenConversationIdsKey(serverUrl), list);
      await prefs.remove(_hiddenConversationIdsPrefix);
    }
    return list.toSet();
  }

  Future<void> addHiddenConversationId(String serverUrl, String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_hiddenConversationIdsKey(serverUrl)) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_hiddenConversationIdsKey(serverUrl), list);
    }
    await prefs.remove(_hiddenConversationIdsPrefix);
  }
}

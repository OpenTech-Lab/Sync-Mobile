import 'package:shared_preferences/shared_preferences.dart';

class ChatUiPreferences {
  static const _typingStyleModeEnabledKey = 'chat_typing_style_mode_enabled';
  static const _typingStyleSpeedMsKey = 'chat_typing_style_speed_ms';
  static const defaultTypingStyleSpeedMs = 18;
  static const minTypingStyleSpeedMs = 8;
  static const maxTypingStyleSpeedMs = 60;

  Future<bool> readTypingStyleModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_typingStyleModeEnabledKey) ?? false;
  }

  Future<void> writeTypingStyleModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_typingStyleModeEnabledKey, enabled);
  }

  Future<int> readTypingStyleSpeedMs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getInt(_typingStyleSpeedMsKey) ?? defaultTypingStyleSpeedMs;
    return raw.clamp(minTypingStyleSpeedMs, maxTypingStyleSpeedMs);
  }

  Future<void> writeTypingStyleSpeedMs(int milliseconds) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = milliseconds.clamp(
      minTypingStyleSpeedMs,
      maxTypingStyleSpeedMs,
    );
    await prefs.setInt(_typingStyleSpeedMsKey, clamped);
  }
}

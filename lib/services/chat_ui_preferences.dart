import 'package:shared_preferences/shared_preferences.dart';

class ChatUiPreferences {
  static const _typingStyleModeEnabledKey = 'chat_typing_style_mode_enabled';

  Future<bool> readTypingStyleModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_typingStyleModeEnabledKey) ?? false;
  }

  Future<void> writeTypingStyleModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_typingStyleModeEnabledKey, enabled);
  }
}

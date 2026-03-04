import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/chat_ui_preferences.dart';

final typingStyleModeControllerProvider =
    AsyncNotifierProvider<TypingStyleModeController, bool>(
      TypingStyleModeController.new,
    );

class TypingStyleModeController extends AsyncNotifier<bool> {
  final _preferences = ChatUiPreferences();

  @override
  Future<bool> build() {
    return _preferences.readTypingStyleModeEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    await _preferences.writeTypingStyleModeEnabled(enabled);
    state = AsyncData(enabled);
  }
}

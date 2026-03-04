import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/chat_ui_preferences.dart';

final typingStyleModeControllerProvider =
    AsyncNotifierProvider<TypingStyleModeController, bool>(
      TypingStyleModeController.new,
    );
final typingStyleSpeedControllerProvider =
    AsyncNotifierProvider<TypingStyleSpeedController, int>(
      TypingStyleSpeedController.new,
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

class TypingStyleSpeedController extends AsyncNotifier<int> {
  final _preferences = ChatUiPreferences();

  @override
  Future<int> build() {
    return _preferences.readTypingStyleSpeedMs();
  }

  Future<void> setSpeedMs(int milliseconds) async {
    await _preferences.writeTypingStyleSpeedMs(milliseconds);
    final next = await _preferences.readTypingStyleSpeedMs();
    state = AsyncData(next);
  }
}

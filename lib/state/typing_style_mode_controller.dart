import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_controller.dart';
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
    final serverUrl = ref.watch(activeServerUrlProvider);
    if (serverUrl == null) {
      return Future.value(false);
    }
    return _preferences.readTypingStyleModeEnabled(serverUrl);
  }

  Future<void> setEnabled(bool enabled) async {
    final serverUrl = ref.read(activeServerUrlProvider);
    if (serverUrl == null) {
      return;
    }
    await _preferences.writeTypingStyleModeEnabled(serverUrl, enabled);
    state = AsyncData(enabled);
  }
}

class TypingStyleSpeedController extends AsyncNotifier<int> {
  final _preferences = ChatUiPreferences();

  @override
  Future<int> build() {
    final serverUrl = ref.watch(activeServerUrlProvider);
    if (serverUrl == null) {
      return Future.value(ChatUiPreferences.defaultTypingStyleSpeedMs);
    }
    return _preferences.readTypingStyleSpeedMs(serverUrl);
  }

  Future<void> setSpeedMs(int milliseconds) async {
    final serverUrl = ref.read(activeServerUrlProvider);
    if (serverUrl == null) {
      return;
    }
    await _preferences.writeTypingStyleSpeedMs(serverUrl, milliseconds);
    final next = await _preferences.readTypingStyleSpeedMs(serverUrl);
    state = AsyncData(next);
  }
}

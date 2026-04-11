import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_controller.dart';
import '../services/chat_ui_preferences.dart';

final hiddenConversationIdsProvider =
    AsyncNotifierProvider<HiddenConversationIdsController, Set<String>>(
      HiddenConversationIdsController.new,
    );

class HiddenConversationIdsController extends AsyncNotifier<Set<String>> {
  final _preferences = ChatUiPreferences();

  @override
  Future<Set<String>> build() {
    final serverUrl = ref.watch(activeServerUrlProvider);
    if (serverUrl == null) {
      return Future.value(const <String>{});
    }
    return _preferences.readHiddenConversationIds(serverUrl);
  }

  Future<void> hide(String conversationId) async {
    final serverUrl = ref.read(activeServerUrlProvider);
    if (serverUrl == null || conversationId.trim().isEmpty) {
      return;
    }
    await _preferences.addHiddenConversationId(serverUrl, conversationId);
    final next = {...(state.value ?? const <String>{}), conversationId};
    state = AsyncData(next);
  }

  Future<void> unhide(String conversationId) async {
    final serverUrl = ref.read(activeServerUrlProvider);
    if (serverUrl == null || conversationId.trim().isEmpty) {
      return;
    }
    await _preferences.removeHiddenConversationId(serverUrl, conversationId);
    final next = {...(state.value ?? const <String>{})}..remove(conversationId);
    state = AsyncData(next);
  }
}

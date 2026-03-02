import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conversation_messages_controller.dart';

final unreadCountsProvider =
    AsyncNotifierProvider<UnreadCountsController, Map<String, int>>(
  UnreadCountsController.new,
);

class UnreadCountsController extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async {
    return <String, int>{};
  }

  Future<void> refresh({
    required String baseUrl,
    required String accessToken,
  }) async {
    final remote = ref.read(remoteChatServiceProvider);
    final counts = await remote.getUnreadCounts(
      baseUrl: baseUrl,
      accessToken: accessToken,
    );
    state = AsyncData(counts);
  }

  void clearForPartner(String partnerId) {
    final current = state.value ?? <String, int>{};
    if (!current.containsKey(partnerId)) {
      return;
    }

    final next = Map<String, int>.from(current)..remove(partnerId);
    state = AsyncData(next);
  }
}

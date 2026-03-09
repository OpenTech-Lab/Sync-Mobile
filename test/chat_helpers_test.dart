import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chats/utils/chat_helpers.dart';

void main() {
  test(
    'chat pane transition offsets match list and conversation directions',
    () {
      expect(
        chatPaneTransitionBeginOffset(ChatPaneKind.list),
        const Offset(-0.12, 0),
      );
      expect(
        chatPaneTransitionBeginOffset(ChatPaneKind.conversation),
        const Offset(1, 0),
      );
    },
  );
}

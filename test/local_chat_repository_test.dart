import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/local_chat_message.dart';
import 'package:mobile/services/local_chat_repository.dart';

void main() {
  test('InMemoryChatRepository.listMessages returns newest-first by timestamp', () async {
    final repo = InMemoryChatRepository();
    const conversationId = 'partner-1';

    await repo.upsertMessages([
      LocalChatMessage(
        id: 'older',
        conversationId: conversationId,
        senderId: 'peer',
        body: 'older',
        createdAt: DateTime.utc(2026, 3, 4, 10, 0, 0),
      ),
      LocalChatMessage(
        id: 'newer',
        conversationId: conversationId,
        senderId: 'peer',
        body: 'newer',
        createdAt: DateTime.utc(2026, 3, 5, 10, 0, 0),
      ),
      LocalChatMessage(
        id: 'middle',
        conversationId: conversationId,
        senderId: 'peer',
        body: 'middle',
        createdAt: DateTime.utc(2026, 3, 4, 18, 0, 0),
      ),
    ]);

    final messages = await repo.listMessages(conversationId: conversationId);
    expect(messages.map((m) => m.id).toList(), ['newer', 'middle', 'older']);
  });
}

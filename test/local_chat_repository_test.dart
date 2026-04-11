import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/chat_room.dart';
import 'package:mobile/models/local_chat_message.dart';
import 'package:mobile/services/local_chat_repository.dart';

void main() {
  test(
    'InMemoryChatRepository.listMessages returns newest-first by timestamp',
    () async {
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
    },
  );

  test(
    'InMemoryChatRepository.listConversations includes room summaries',
    () async {
      final repo = InMemoryChatRepository();
      final room = ChatRoom(
        id: 'room-1',
        name: 'Weekend plans',
        memberCount: 3,
        unreadCount: 2,
        createdAt: DateTime.utc(2026, 3, 6, 8, 0, 0),
        updatedAt: DateTime.utc(2026, 3, 6, 8, 5, 0),
        lastMessagePreview: 'Meet at 7?',
        lastMessageAt: DateTime.utc(2026, 3, 6, 8, 4, 0),
      );

      await repo.replaceRooms([room]);

      final summaries = await repo.listConversations();
      expect(summaries, hasLength(1));
      expect(summaries.first.conversationId, room.conversationId);
      expect(summaries.first.title, 'Weekend plans');
      expect(summaries.first.unreadCount, 2);
      expect(summaries.first.lastBody, 'Meet at 7?');
    },
  );
}

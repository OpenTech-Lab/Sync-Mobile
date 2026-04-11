import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/local_chat_message.dart';

void main() {
  test('toMap/fromMap roundtrip preserves fields', () {
    final original = LocalChatMessage(
      id: 'm_1',
      conversationId: 'local-default',
      senderId: 'me',
      body: 'Hello',
      createdAt: DateTime.utc(2026, 3, 2, 10, 30),
    );

    final roundtrip = LocalChatMessage.fromMap(original.toMap());

    expect(roundtrip.id, original.id);
    expect(roundtrip.conversationId, original.conversationId);
    expect(roundtrip.senderId, original.senderId);
    expect(roundtrip.body, original.body);
    expect(roundtrip.createdAt, original.createdAt);
  });
}

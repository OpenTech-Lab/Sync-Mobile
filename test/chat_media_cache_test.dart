import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chats/utils/chat_media_cache.dart';
import 'package:mobile/models/local_chat_message.dart';
import 'package:mobile/models/sticker.dart';

void main() {
  LocalChatMessage messageWithMedia(String id, {String text = 'caption'}) {
    final payload = base64Encode(List<int>.generate(16, (index) => index));
    return LocalChatMessage(
      id: id,
      conversationId: 'friend-1',
      senderId: 'friend-1',
      body: '$text\n[media-data:$payload]',
      createdAt: DateTime.utc(2026, 3, 10),
    );
  }

  Sticker sticker(String id) => Sticker(
    id: id,
    groupName: 'General',
    name: 'sticker-$id',
    mimeType: 'image/png',
    contentBase64: base64Encode(List<int>.generate(12, (index) => index)),
    status: 'active',
    createdAt: DateTime.utc(2026, 3, 10),
  );

  test('parseInlineMedia strips media token and keeps provider stable', () {
    final message = messageWithMedia('m-1');

    final first = ChatMediaCache.parseInlineMedia(message);
    final second = ChatMediaCache.parseInlineMedia(message);

    expect(first, isNotNull);
    expect(first!.text, 'caption');
    expect(second, isNotNull);
    expect(first.imageProvider, same(second!.imageProvider));
  });

  test('parseStickerId extracts sticker identifier', () {
    expect(ChatMediaCache.parseStickerId('[sticker:abc123:wave]'), 'abc123');
    expect(ChatMediaCache.parseStickerId('hello'), isNull);
  });

  test(
    'resolveStickerImage keeps provider stable for same sticker payload',
    () {
      final first = ChatMediaCache.resolveStickerImage(sticker('s-1'));
      final second = ChatMediaCache.resolveStickerImage(sticker('s-1'));

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first, same(second));
    },
  );
}

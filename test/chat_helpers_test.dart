import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chats/utils/chat_helpers.dart';

void main() {
  test('chat pane background parallax matches Cupertino-style factor', () {
    expect(
      chatPaneBackgroundParallaxProgress(1, linearTransition: true),
      chatPaneBackgroundParallaxFactor,
    );
    expect(chatPaneBackgroundParallaxProgress(0, linearTransition: true), 0);
  });

  test('chat back gesture completion handles drag progress and fling', () {
    expect(
      shouldCompleteChatBackGesture(
        transitionProgress: 0.9,
        velocity: chatPaneBackGestureVelocityThreshold + 1,
      ),
      isTrue,
    );
    expect(
      shouldCompleteChatBackGesture(
        transitionProgress: 1 - chatPaneBackGestureDismissThreshold + 0.01,
        velocity: 0,
      ),
      isFalse,
    );
    expect(
      shouldCompleteChatBackGesture(
        transitionProgress: 1 - chatPaneBackGestureDismissThreshold,
        velocity: 0,
      ),
      isTrue,
    );
  });

  test(
    'friend tag filter matches only tagged direct-message conversations',
    () {
      const friendTagsById = <String, List<String>>{
        'friend-a': ['Work', 'VIP'],
        'friend-b': ['Family'],
      };

      expect(
        conversationMatchesSelectedFriendTag(
          conversationId: 'friend-a',
          selectedFriendTag: 'Work',
          friendTagsById: friendTagsById,
        ),
        isTrue,
      );
      expect(
        conversationMatchesSelectedFriendTag(
          conversationId: 'friend-b',
          selectedFriendTag: 'Work',
          friendTagsById: friendTagsById,
        ),
        isFalse,
      );
      expect(
        conversationMatchesSelectedFriendTag(
          conversationId: 'room:room-1',
          selectedFriendTag: 'Work',
          friendTagsById: friendTagsById,
        ),
        isFalse,
      );
      expect(
        conversationMatchesSelectedFriendTag(
          conversationId: 'room:room-1',
          selectedFriendTag: null,
          friendTagsById: friendTagsById,
        ),
        isTrue,
      );
    },
  );
}

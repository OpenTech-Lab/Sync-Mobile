import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chats/widgets/conversation_starter.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/services/local_chat_repository.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tag filters render and report selection changes', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    String? selectedTag = 'Work';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ConversationStarter(
              controller: controller,
              focusNode: focusNode,
              unreadCounts: const <String, int>{},
              orderedConversationIds: const <String>[],
              summariesById: const <String, ConversationSummary>{},
              availableFriendTags: const <String>['Family', 'Work'],
              selectedFriendTag: selectedTag,
              onSelectedFriendTag: (tag) => selectedTag = tag,
              onQuickAction: (_) {},
              onOpenConversation: (_) {},
              onClearConversation: (_) async {},
              onMarkAllRead: () async {},
              onStartNewChat: () {},
              onAddFriend: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('friend_tag_filter_all')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('friend_tag_filter_Family')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('friend_tag_filter_Work')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('friend_tag_filter_Family')));
    await tester.pumpAndSettle();
    expect(selectedTag, 'Family');

    await tester.tap(find.byKey(const ValueKey('friend_tag_filter_all')));
    await tester.pumpAndSettle();
    expect(selectedTag, isNull);
  });

  testWidgets('overflow tags stay in a right-side horizontal scroller', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    const farRightTag = 'Neighborhood Circle';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 260,
                child: ConversationStarter(
                  controller: controller,
                  focusNode: focusNode,
                  unreadCounts: const <String, int>{},
                  orderedConversationIds: const <String>['friend-a'],
                  summariesById: <String, ConversationSummary>{
                    'friend-a': ConversationSummary(
                      conversationId: 'friend-a',
                      lastBody: 'hello',
                      lastAt: DateTime.utc(2026, 3, 12, 10, 0),
                    ),
                  },
                  availableFriendTags: const <String>[
                    'Family Group',
                    'Work Friends',
                    'Tennis Club',
                    farRightTag,
                  ],
                  onQuickAction: (_) {},
                  onOpenConversation: (_) {},
                  onClearConversation: (_) async {},
                  onMarkAllRead: () async {},
                  onStartNewChat: () {},
                  onAddFriend: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final allRect = tester.getRect(
      find.byKey(const ValueKey('friend_tag_filter_all')),
    );
    final scrollRect = tester.getRect(
      find.byKey(const ValueKey('friend_tag_filter_scroll')),
    );
    final hiddenTagFinder = find.byKey(
      ValueKey('friend_tag_filter_$farRightTag'),
    );
    final hiddenTagRect = tester.getRect(hiddenTagFinder);

    expect(allRect.right, lessThanOrEqualTo(scrollRect.left));
    expect(hiddenTagRect.left, greaterThanOrEqualTo(scrollRect.right));

    await tester.dragUntilVisible(
      hiddenTagFinder,
      find.byKey(const ValueKey('friend_tag_filter_scroll')),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();

    final revealedTagRect = tester.getRect(hiddenTagFinder);
    expect(revealedTagRect.left, lessThan(scrollRect.right));
  });

  testWidgets('tag filters sit close to CHATS when unread is empty', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ConversationStarter(
              controller: controller,
              focusNode: focusNode,
              unreadCounts: const <String, int>{},
              orderedConversationIds: const <String>['friend-a'],
              summariesById: <String, ConversationSummary>{
                'friend-a': ConversationSummary(
                  conversationId: 'friend-a',
                  lastBody: 'hello',
                  lastAt: DateTime.utc(2026, 3, 12, 10, 0),
                ),
              },
              availableFriendTags: const <String>['Work'],
              onQuickAction: (_) {},
              onOpenConversation: (_) {},
              onClearConversation: (_) async {},
              onMarkAllRead: () async {},
              onStartNewChat: () {},
              onAddFriend: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final filtersRect = tester.getRect(
      find.byKey(const ValueKey('friend_tag_filters')),
    );
    final chatsHeaderRect = tester.getRect(
      find.byKey(const ValueKey('chats_header')),
    );

    expect(chatsHeaderRect.top - filtersRect.bottom, closeTo(24, 0.1));
  });

  testWidgets('room rows show member count in the title', (tester) async {
    const roomConversationId = 'room:room-1';
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ConversationStarter(
              controller: controller,
              focusNode: focusNode,
              unreadCounts: const <String, int>{},
              orderedConversationIds: const <String>[roomConversationId],
              summariesById: <String, ConversationSummary>{
                roomConversationId: ConversationSummary(
                  conversationId: roomConversationId,
                  title: 'My Room',
                  memberCount: 12,
                  lastBody: 'last message',
                  lastAt: DateTime.utc(2026, 3, 12, 10, 0),
                ),
              },
              onQuickAction: (_) {},
              onOpenConversation: (_) {},
              onClearConversation: (_) async {},
              onMarkAllRead: () async {},
              onStartNewChat: () {},
              onAddFriend: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Room (12)'), findsOneWidget);
  });

  testWidgets('swiping a chat row reveals Delete and clears on tap', (
    tester,
  ) async {
    const serverUrl = 'https://example.com';
    const friendId = 'friend-user-id';

    SharedPreferences.setMockInitialValues({
      'profile_display_name::example.com::$friendId': 'Friend User',
    });

    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    var deletedConversationId = '';
    var deleted = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeServerUrlProvider.overrideWithValue(serverUrl)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                final orderedConversationIds = deleted
                    ? const <String>[]
                    : const <String>[friendId];
                final summariesById = deleted
                    ? const <String, ConversationSummary>{}
                    : <String, ConversationSummary>{
                        friendId: ConversationSummary(
                          conversationId: friendId,
                          lastBody: 'hello',
                          lastAt: DateTime.utc(2026, 3, 12, 10, 0),
                        ),
                      };
                return ConversationStarter(
                  controller: controller,
                  focusNode: focusNode,
                  unreadCounts: const <String, int>{},
                  orderedConversationIds: orderedConversationIds,
                  summariesById: summariesById,
                  onQuickAction: (_) {},
                  onOpenConversation: (_) {},
                  onClearConversation: (conversationId) async {
                    deletedConversationId = conversationId;
                    setState(() => deleted = true);
                  },
                  onMarkAllRead: () async {},
                  onStartNewChat: () {},
                  onAddFriend: () {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('convo_friend-user-id'));
    expect(row, findsOneWidget);
    final deleteAction = find.text('Delete');
    expect(deleteAction, findsOneWidget);

    final rowRect = tester.getRect(row);
    final hiddenDeleteRect = tester.getRect(deleteAction);
    expect(hiddenDeleteRect.left, greaterThanOrEqualTo(rowRect.right));

    await tester.drag(row, const Offset(-160, 0));
    await tester.pumpAndSettle();

    final revealedDeleteRect = tester.getRect(deleteAction);
    expect(revealedDeleteRect.left, lessThan(rowRect.right));
    expect(revealedDeleteRect.right, lessThanOrEqualTo(rowRect.right));

    await tester.tap(deleteAction);
    await tester.pumpAndSettle();

    expect(deletedConversationId, friendId);
    expect(find.byKey(const ValueKey('convo_friend-user-id')), findsNothing);
  });

  testWidgets('swiping a room row reveals Delete and clears on tap', (
    tester,
  ) async {
    const roomConversationId = 'room:room-1';

    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    var deletedConversationId = '';
    var deleted = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                final orderedConversationIds = deleted
                    ? const <String>[]
                    : const <String>[roomConversationId];
                final summariesById = deleted
                    ? const <String, ConversationSummary>{}
                    : <String, ConversationSummary>{
                        roomConversationId: ConversationSummary(
                          conversationId: roomConversationId,
                          title: 'Focus Room',
                          memberCount: 3,
                          lastBody: 'hello room',
                          lastAt: DateTime.utc(2026, 3, 12, 10, 0),
                        ),
                      };
                return ConversationStarter(
                  controller: controller,
                  focusNode: focusNode,
                  unreadCounts: const <String, int>{},
                  orderedConversationIds: orderedConversationIds,
                  summariesById: summariesById,
                  onQuickAction: (_) {},
                  onOpenConversation: (_) {},
                  onClearConversation: (conversationId) async {
                    deletedConversationId = conversationId;
                    setState(() => deleted = true);
                  },
                  onMarkAllRead: () async {},
                  onStartNewChat: () {},
                  onAddFriend: () {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('convo_room:room-1'));
    expect(row, findsOneWidget);
    final deleteAction = find.text('Delete');
    expect(deleteAction, findsOneWidget);

    final rowRect = tester.getRect(row);
    final hiddenDeleteRect = tester.getRect(deleteAction);
    expect(hiddenDeleteRect.left, greaterThanOrEqualTo(rowRect.right));

    await tester.drag(row, const Offset(-160, 0));
    await tester.pumpAndSettle();

    final revealedDeleteRect = tester.getRect(deleteAction);
    expect(revealedDeleteRect.left, lessThan(rowRect.right));
    expect(revealedDeleteRect.right, lessThanOrEqualTo(rowRect.right));

    await tester.tap(deleteAction);
    await tester.pumpAndSettle();

    expect(deletedConversationId, roomConversationId);
    expect(find.byKey(const ValueKey('convo_room:room-1')), findsNothing);
  });
}

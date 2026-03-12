import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chats/widgets/conversation_starter.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/services/local_chat_repository.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

    await tester.drag(row, const Offset(-160, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(deletedConversationId, friendId);
    expect(find.byKey(const ValueKey('convo_friend-user-id')), findsNothing);
  });
}

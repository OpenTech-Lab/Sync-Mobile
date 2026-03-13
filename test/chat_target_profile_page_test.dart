import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chats/chat_target_profile_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/services/user_profile_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('friend tags created on one profile are reusable on another', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = UserProfilePreferences();
    const serverUrl = 'https://example.com';

    Future<void> pumpProfile({
      required String userId,
      required String displayName,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatTargetProfileScreen(
            serverUrl: serverUrl,
            userId: userId,
            displayName: displayName,
            displayHandle: userId,
            avatarBase64: null,
            isFriend: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpProfile(userId: 'friend-a', displayName: 'Friend A');

    expect(find.text('No tags yet'), findsOneWidget);

    await tester.tap(find.text('ADD TAGS'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Work');
    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();
    final createdTagFinder = find.byKey(
      const ValueKey('friend_tag_option_Work'),
    );
    expect(createdTagFinder, findsOneWidget);
    expect(tester.widget<InputChip>(createdTagFinder).selected, isTrue);
    await tester.tap(find.text('S A V E'));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
    expect(await preferences.readFriendTags(serverUrl, 'friend-a'), ['Work']);

    await pumpProfile(userId: 'friend-b', displayName: 'Friend B');

    await tester.tap(find.text('ADD TAGS'));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('S A V E'));
    await tester.pumpAndSettle();

    expect(await preferences.readFriendTags(serverUrl, 'friend-b'), ['Work']);
    expect(await preferences.readFriendTagCatalog(serverUrl), ['Work']);
  });

  testWidgets(
    'deleting a tag removes it from the reusable list for all friends',
    (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final preferences = UserProfilePreferences();
      const serverUrl = 'https://example.com';

      await preferences.addFriendId(serverUrl, 'friend-a');
      await preferences.addFriendId(serverUrl, 'friend-b');
      await preferences.writeFriendTags(serverUrl, 'friend-a', ['Work', 'VIP']);
      await preferences.writeFriendTags(serverUrl, 'friend-b', ['Work']);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChatTargetProfileScreen(
            serverUrl: serverUrl,
            userId: 'friend-a',
            displayName: 'Friend A',
            displayHandle: 'friend-a',
            avatarBase64: null,
            isFriend: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('EDIT TAGS'));
      await tester.pumpAndSettle();

      final workChip = find.byKey(const ValueKey('friend_tag_option_Work'));
      expect(workChip, findsOneWidget);

      await tester.tap(
        find.descendant(of: workChip, matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('D E L E T E'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('S A V E'));
      await tester.pumpAndSettle();

      expect(await preferences.readFriendTags(serverUrl, 'friend-a'), ['VIP']);
      expect(await preferences.readFriendTags(serverUrl, 'friend-b'), isEmpty);
      expect(await preferences.readFriendTagCatalog(serverUrl), ['VIP']);
      expect(find.text('Work'), findsNothing);
    },
  );

  testWidgets(
    'cancel friend shows confirmation dialog before returning action',
    (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final navigatorKey = GlobalKey<NavigatorState>();
      late Future<ChatTargetProfileAction?> resultFuture;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    resultFuture = Navigator.of(context).push(
                      MaterialPageRoute<ChatTargetProfileAction>(
                        builder: (_) => const ChatTargetProfileScreen(
                          serverUrl: 'https://example.com',
                          userId: 'friend-a',
                          displayName: 'Friend A',
                          displayHandle: 'friend-a',
                          avatarBase64: null,
                          isFriend: true,
                        ),
                      ),
                    );
                  },
                  child: const Text('OPEN'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CANCEL FRIEND'));
      await tester.pumpAndSettle();

      expect(
        find.text('Remove Friend A from your friend list?'),
        findsOneWidget,
      );

      await tester.tap(find.text('cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatTargetProfileScreen), findsOneWidget);

      await tester.tap(find.text('CANCEL FRIEND'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCEL FRIEND').last);
      await tester.pumpAndSettle();

      await expectLater(
        resultFuture,
        completion(ChatTargetProfileAction.cancelFriend),
      );
    },
  );

  testWidgets(
    'description is shown under username and about section is removed',
    (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChatTargetProfileScreen(
            serverUrl: 'https://example.com',
            userId: 'friend-a',
            displayName: 'Friend A',
            displayHandle: 'friend-a',
            avatarBase64: null,
            description: 'Quiet observer from another planet.',
            isFriend: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Friend A'), findsOneWidget);
      expect(find.text('Quiet observer from another planet.'), findsOneWidget);
      expect(find.text('ABOUT'), findsNothing);
    },
  );
}

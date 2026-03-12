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
}

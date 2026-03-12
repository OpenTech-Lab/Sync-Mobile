import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/services/local_chat_repository.dart';
import 'package:mobile/services/server_scope.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:mobile/state/conversation_messages_controller.dart';
import 'package:mobile/state/user_profile_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'home shows one-line description previews for my card and friend rows',
    (tester) async {
      const serverUrl = 'https://example.com';
      const currentUserId = 'current-user-id';
      const friendId = 'friend-user-id';
      const myDescription =
          'My description is intentionally long so the home profile card must clamp it to one visible row.';
      const friendDescription =
          'Friend description is also long enough that the friend row must rely on ellipsis instead of wrapping.';
      final scope = serverDomainKeyFromUrl(serverUrl);

      SharedPreferences.setMockInitialValues({
        'friend_ids::$scope': [friendId],
        'profile_display_name::$scope::$currentUserId': 'Current User',
        'profile_description::$scope::$currentUserId': myDescription,
        'profile_display_name::$scope::$friendId': 'Friend User',
        'profile_description::$scope::$friendId': friendDescription,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerUrlProvider.overrideWithValue(serverUrl),
            chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
            myGuildSnapshotProvider.overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeTab(
              serverUrl: serverUrl,
              accessToken: 'token',
              currentUserId: currentUserId,
              currentUsername: 'Current User',
              planetInfo: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('View profile'), findsNothing);

      final myDescriptionText = tester.widget<Text>(find.text(myDescription));
      expect(myDescriptionText.maxLines, 1);
      expect(myDescriptionText.overflow, TextOverflow.ellipsis);

      final friendDescriptionText = tester.widget<Text>(
        find.text(friendDescription),
      );
      expect(friendDescriptionText.maxLines, 1);
      expect(friendDescriptionText.overflow, TextOverflow.ellipsis);
    },
  );
}

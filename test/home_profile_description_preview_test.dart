import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/services/local_chat_repository.dart';
import 'package:mobile/services/remote_user_profile_service.dart';
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
            remoteUserProfileServiceProvider.overrideWithValue(
              _FakeRemoteUserProfileService(),
            ),
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

  testWidgets(
    'home my-profile block shows guild badges inline after username',
    (tester) async {
      const serverUrl = 'https://example.com';
      const currentUserId = 'current-user-id';
      final scope = serverDomainKeyFromUrl(serverUrl);

      SharedPreferences.setMockInitialValues({
        'profile_display_name::$scope::$currentUserId': 'Current User',
        'profile_description::$scope::$currentUserId': 'About me',
      });

      const guild = UserGuildSnapshot(
        activeDays: 12,
        level: 7,
        contributionScore: 120,
        rank: 'Explorer',
        nextLevelActiveDays: 20,
        levelProgressPercent: 60,
        dailyOutboundMessagesEnforced: true,
        dailyOutboundMessagesLimit: 30,
        dailyOutboundMessagesSent: 12,
        dailyOutboundMessagesRemaining: 18,
        dailyAttachmentSendsEnforced: true,
        dailyAttachmentSendLimit: 5,
        dailyAttachmentSendsSent: 1,
        dailyAttachmentSendsRemaining: 4,
        allowedAttachmentTypes: <String>['image'],
        dailyFriendAddsEnforced: true,
        dailyFriendAddLimit: 10,
        dailyFriendAddsSent: 2,
        dailyFriendAddsRemaining: 8,
        challengeState: 'none',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerUrlProvider.overrideWithValue(serverUrl),
            chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
            myGuildSnapshotProvider.overrideWith((ref) async => guild),
            remoteUserProfileServiceProvider.overrideWithValue(
              _FakeRemoteUserProfileService(),
            ),
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

      final usernameFinder = find.byKey(
        const ValueKey('home_profile_username'),
      );
      final gapFinder = find.byKey(const ValueKey('home_profile_badge_gap'));
      final levelBadgeFinder = find.byKey(
        const ValueKey('home_profile_level_badge'),
      );
      final rankBadgeFinder = find.byKey(
        const ValueKey('home_profile_rank_badge'),
      );

      final usernameRect = tester.getRect(usernameFinder);
      final levelRect = tester.getRect(levelBadgeFinder);
      final rankRect = tester.getRect(rankBadgeFinder);
      final usernameCenter = tester.getCenter(usernameFinder);
      final levelCenter = tester.getCenter(levelBadgeFinder);
      final rankCenter = tester.getCenter(rankBadgeFinder);

      expect(find.text('Lv 7'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
      expect(tester.getSize(gapFinder).width, 8);
      expect(levelRect.left, greaterThan(usernameRect.right));
      expect(rankRect.left, greaterThan(levelRect.right));
      expect((usernameCenter.dy - levelCenter.dy).abs(), lessThan(1));
      expect((levelCenter.dy - rankCenter.dy).abs(), lessThan(1));
    },
  );
}

class _FakeRemoteUserProfileService extends RemoteUserProfileService {
  _FakeRemoteUserProfileService();

  static const _friendDescription =
      'Friend description is also long enough that the friend row must rely on ellipsis instead of wrapping.';

  @override
  Future<UserProfile> getMyProfile({
    required String baseUrl,
    required String accessToken,
  }) async {
    return const UserProfile(
      id: 'current-user-id',
      username: 'Current User',
      avatarBase64: null,
      description: null,
      messagePublicKey: null,
    );
  }

  @override
  Future<UserProfile> getUserProfile({
    required String baseUrl,
    required String accessToken,
    required String userId,
  }) async {
    return UserProfile(
      id: userId,
      username: 'Friend User',
      avatarBase64: null,
      description: _friendDescription,
      messagePublicKey: null,
    );
  }
}

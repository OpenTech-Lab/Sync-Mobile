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
    'home friend rows sync and display remote descriptions under the friend name',
    (tester) async {
      const serverUrl = 'https://example.com';
      const currentUserId = 'current-user-id';
      const friendId = 'friend-user-id';
      const remoteDescription = 'Remote friend status message';
      final scope = serverDomainKeyFromUrl(serverUrl);

      SharedPreferences.setMockInitialValues({
        'friend_ids::$scope': [friendId],
        'profile_display_name::$scope::$currentUserId': 'Current User',
        'profile_display_name::$scope::$friendId': 'Friend User',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerUrlProvider.overrideWithValue(serverUrl),
            chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
            myGuildSnapshotProvider.overrideWith((ref) async => null),
            remoteUserProfileServiceProvider.overrideWithValue(
              _FriendDescriptionRemoteUserProfileService(),
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

      expect(find.text(remoteDescription), findsOneWidget);
      final subtitle = tester.widget<Text>(find.text(remoteDescription));
      expect(subtitle.maxLines, 1);
      expect(subtitle.overflow, TextOverflow.ellipsis);
    },
  );
}

class _FriendDescriptionRemoteUserProfileService
    extends RemoteUserProfileService {
  _FriendDescriptionRemoteUserProfileService();

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
      description: 'Remote friend status message',
      messagePublicKey: null,
    );
  }
}

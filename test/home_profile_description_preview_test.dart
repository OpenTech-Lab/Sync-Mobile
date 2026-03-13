import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/models/chat_room.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/services/local_chat_repository.dart';
import 'package:mobile/services/remote_chat_service.dart';
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

  testWidgets('home room rows show two-line member summaries with ellipsis', (
    tester,
  ) async {
    const serverUrl = 'https://example.com';
    const currentUserId = 'current-user-id';
    final scope = serverDomainKeyFromUrl(serverUrl);
    final repo = InMemoryChatRepository();
    await repo.replaceRooms([
      ChatRoom(
        id: 'room-1',
        name: 'Focus Room',
        memberCount: 3,
        unreadCount: 0,
        createdAt: DateTime.utc(2026, 3, 12, 10, 0),
        updatedAt: DateTime.utc(2026, 3, 12, 10, 0),
      ),
    ]);

    SharedPreferences.setMockInitialValues({
      'profile_display_name::$scope::$currentUserId': 'Current User',
      'profile_description::$scope::$currentUserId': 'About me',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeServerUrlProvider.overrideWithValue(serverUrl),
          appControllerProvider.overrideWith(_FakeAppController.new),
          chatRepositoryProvider.overrideWithValue(repo),
          myGuildSnapshotProvider.overrideWith((ref) async => null),
          remoteChatServiceProvider.overrideWithValue(
            _FakeHomeRemoteChatService(),
          ),
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

    final titleFinder = find.byKey(const ValueKey('home_room_title_room-1'));
    final membersFinder = find.byKey(
      const ValueKey('home_room_members_room-1'),
    );
    final titleText = tester.widget<Text>(titleFinder);
    final membersText = tester.widget<Text>(membersFinder);

    expect(find.text('Focus Room (3)'), findsOneWidget);
    expect(
      find.text('Alpha, Beta, Gamma With Long Name, Delta, Echo'),
      findsOneWidget,
    );
    expect(titleText.maxLines, 1);
    expect(titleText.overflow, TextOverflow.ellipsis);
    expect(membersText.maxLines, 1);
    expect(membersText.overflow, TextOverflow.ellipsis);
    expect(
      tester.getCenter(membersFinder).dy,
      greaterThan(tester.getCenter(titleFinder).dy),
    );
  });

  testWidgets(
    'home keeps room and friend rows close to their section dividers',
    (tester) async {
      const serverUrl = 'https://example.com';
      const currentUserId = 'current-user-id';
      const friendId = 'friend-user-id';
      final scope = serverDomainKeyFromUrl(serverUrl);
      final repo = InMemoryChatRepository();
      await repo.replaceRooms([
        ChatRoom(
          id: 'room-1',
          name: 'Focus Room',
          memberCount: 3,
          unreadCount: 0,
          createdAt: DateTime.utc(2026, 3, 12, 10, 0),
          updatedAt: DateTime.utc(2026, 3, 12, 10, 0),
        ),
      ]);

      SharedPreferences.setMockInitialValues({
        'friend_ids::$scope': [friendId],
        'profile_display_name::$scope::$currentUserId': 'Current User',
        'profile_description::$scope::$currentUserId': 'About me',
        'profile_display_name::$scope::$friendId': 'Friend User',
        'profile_description::$scope::$friendId': 'Friend description',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerUrlProvider.overrideWithValue(serverUrl),
            appControllerProvider.overrideWith(_FakeAppController.new),
            chatRepositoryProvider.overrideWithValue(repo),
            myGuildSnapshotProvider.overrideWith((ref) async => null),
            remoteChatServiceProvider.overrideWithValue(
              _FakeHomeRemoteChatService(),
            ),
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

      final roomsDividerRect = tester.getRect(
        find.byKey(const ValueKey('home_rooms_section_divider')),
      );
      final roomRowRect = tester.getRect(
        find.byKey(const ValueKey('home_room_row_room-1')),
      );
      final friendsDividerRect = tester.getRect(
        find.byKey(const ValueKey('home_friends_section_divider')),
      );
      final friendRowRect = tester.getRect(
        find.byKey(const ValueKey('home_friend_row_friend-user-id')),
      );

      expect(roomRowRect.top - roomsDividerRect.bottom, closeTo(5, 0.1));
      expect(friendRowRect.top - friendsDividerRect.bottom, closeTo(5, 0.1));
    },
  );

  testWidgets(
    'home room and friend rows keep avatar and text aligned in compact layout',
    (tester) async {
      const serverUrl = 'https://example.com';
      const currentUserId = 'current-user-id';
      const friendId = 'friend-user-id';
      final scope = serverDomainKeyFromUrl(serverUrl);
      final repo = InMemoryChatRepository();
      await repo.replaceRooms([
        ChatRoom(
          id: 'room-1',
          name: 'Focus Room',
          memberCount: 3,
          unreadCount: 0,
          createdAt: DateTime.utc(2026, 3, 12, 10, 0),
          updatedAt: DateTime.utc(2026, 3, 12, 10, 0),
        ),
      ]);

      SharedPreferences.setMockInitialValues({
        'friend_ids::$scope': [friendId],
        'profile_display_name::$scope::$currentUserId': 'Current User',
        'profile_description::$scope::$currentUserId': 'About me',
        'profile_display_name::$scope::$friendId': 'Friend User',
        'profile_description::$scope::$friendId': 'Friend description',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerUrlProvider.overrideWithValue(serverUrl),
            appControllerProvider.overrideWith(_FakeAppController.new),
            chatRepositoryProvider.overrideWithValue(repo),
            myGuildSnapshotProvider.overrideWith((ref) async => null),
            remoteChatServiceProvider.overrideWithValue(
              _FakeHomeRemoteChatService(),
            ),
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

      final roomRowRect = tester.getRect(
        find.byKey(const ValueKey('home_room_row_room-1')),
      );
      final roomAvatarRect = tester.getRect(
        find.byKey(const ValueKey('home_room_avatar_room-1')),
      );
      final roomTextRect = tester.getRect(
        find.byKey(const ValueKey('home_room_text_room-1')),
      );
      final friendRowRect = tester.getRect(
        find.byKey(const ValueKey('home_friend_row_friend-user-id')),
      );
      final friendAvatarRect = tester.getRect(
        find.byKey(const ValueKey('home_friend_avatar_friend-user-id')),
      );
      final friendTextRect = tester.getRect(
        find.byKey(const ValueKey('home_friend_text_friend-user-id')),
      );

      expect(roomRowRect.height, lessThan(56));
      expect(friendRowRect.height, lessThan(56));
      expect(
        (roomAvatarRect.center.dy - roomRowRect.center.dy).abs(),
        lessThan(1),
      );
      expect(
        (roomTextRect.center.dy - roomRowRect.center.dy).abs(),
        lessThan(1),
      );
      expect(
        (friendAvatarRect.center.dy - friendRowRect.center.dy).abs(),
        lessThan(1),
      );
      expect(
        (friendTextRect.center.dy - friendRowRect.center.dy).abs(),
        lessThan(1),
      );
    },
  );
}

class _FakeAppController extends AppController {
  @override
  Future<AppState> build() async {
    return const AppState(
      serverUrl: 'https://example.com',
      accessToken: 'token',
      currentUserId: 'current-user-id',
      currentUsername: 'Current User',
      savedUserId: 'current-user-id',
      connectionStatus: ConnectionStatus.idle,
      connectionError: null,
      planetInfo: null,
      isSubmitting: false,
      authError: null,
    );
  }

  @override
  Future<String?> ensureFreshAccessToken() async => 'token';
}

class _FakeHomeRemoteChatService extends RemoteChatService {
  _FakeHomeRemoteChatService() : super();

  @override
  Future<RoomDetail> getRoom({
    required String baseUrl,
    required String accessToken,
    required String roomId,
  }) async {
    return RoomDetail(
      id: roomId,
      name: 'Focus Room',
      createdBy: 'current-user-id',
      memberCount: 3,
      createdAt: DateTime.utc(2026, 3, 12, 10, 0),
      updatedAt: DateTime.utc(2026, 3, 12, 10, 0),
      members: [
        RoomMemberProfile(
          userId: 'alpha',
          username: 'Alpha',
          role: 'owner',
          joinedAt: DateTime.utc(2026, 3, 12, 10, 0),
        ),
        RoomMemberProfile(
          userId: 'beta',
          username: 'Beta',
          role: 'member',
          joinedAt: DateTime.utc(2026, 3, 12, 10, 1),
        ),
        RoomMemberProfile(
          userId: 'gamma',
          username: 'Gamma With Long Name',
          role: 'member',
          joinedAt: DateTime.utc(2026, 3, 12, 10, 2),
        ),
        RoomMemberProfile(
          userId: 'delta',
          username: 'Delta',
          role: 'member',
          joinedAt: DateTime.utc(2026, 3, 12, 10, 3),
        ),
        RoomMemberProfile(
          userId: 'echo',
          username: 'Echo',
          role: 'member',
          joinedAt: DateTime.utc(2026, 3, 12, 10, 4),
        ),
      ],
    );
  }
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

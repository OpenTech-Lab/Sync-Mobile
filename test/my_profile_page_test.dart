import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/my_profile_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/services/remote_user_profile_service.dart';
import 'package:mobile/services/server_scope.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:mobile/state/user_profile_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('my profile keeps guild badges in the summary section', (
    tester,
  ) async {
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
          myGuildSnapshotProvider.overrideWith((ref) async => guild),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MyProfileScreen(
            serverUrl: serverUrl,
            accessToken: 'token',
            currentUserId: currentUserId,
            currentUsername: 'Current User',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final usernameFinder = find.text('Current User');
    final levelBadgeFinder = find.text('Level 7');
    final rankBadgeFinder = find.text('Rank Explorer');
    expect(find.text('Level 7'), findsOneWidget);
    expect(find.text('Rank Explorer'), findsOneWidget);

    final usernameRect = tester.getRect(usernameFinder);
    final levelRect = tester.getRect(levelBadgeFinder);
    final rankRect = tester.getRect(rankBadgeFinder);

    expect(levelRect.top, greaterThan(usernameRect.bottom));
    expect(rankRect.top, greaterThan(usernameRect.bottom));
    expect((levelRect.center.dy - rankRect.center.dy).abs(), lessThan(1));
  });

  testWidgets(
    'username edit dialog keeps save reachable on a small phone with keyboard',
    (tester) async {
      const serverUrl = 'https://example.com';
      const currentUserId = 'current-user-id';
      final scope = serverDomainKeyFromUrl(serverUrl);
      final remote = _FakeRemoteUserProfileService(
        username: 'Current User',
        description: 'About me',
      );

      SharedPreferences.setMockInitialValues({
        'profile_display_name::$scope::$currentUserId': 'Current User',
        'profile_description::$scope::$currentUserId': 'About me',
      });

      _setSmallPhoneViewport(tester);

      await tester.pumpWidget(
        _buildProfileApp(
          serverUrl: serverUrl,
          currentUserId: currentUserId,
          remote: remote,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('edit').first);
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Renamed User');
      await tester.pump();
      await tester.tap(find.text('S A V E'));
      await tester.pumpAndSettle();

      expect(remote.lastUsername, 'Renamed User');
      expect(find.text('Renamed User'), findsOneWidget);
      expect(find.text('USERNAME'), findsNothing);
    },
  );

  testWidgets(
    'description edit dialog keeps save reachable on a small phone with keyboard',
    (tester) async {
      const serverUrl = 'https://example.com';
      const currentUserId = 'current-user-id';
      final scope = serverDomainKeyFromUrl(serverUrl);
      final remote = _FakeRemoteUserProfileService(
        username: 'Current User',
        description: 'About me',
      );

      SharedPreferences.setMockInitialValues({
        'profile_display_name::$scope::$currentUserId': 'Current User',
        'profile_description::$scope::$currentUserId': 'About me',
      });

      _setSmallPhoneViewport(tester);

      await tester.pumpWidget(
        _buildProfileApp(
          serverUrl: serverUrl,
          currentUserId: currentUserId,
          remote: remote,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('edit').last);
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Updated short bio');
      await tester.pump();
      await tester.tap(find.text('S A V E'));
      await tester.pumpAndSettle();

      expect(remote.lastDescription, 'Updated short bio');
      expect(find.text('Updated short bio'), findsOneWidget);
      expect(find.text('A few words about yourself'), findsNothing);
    },
  );

  testWidgets(
    'my profile hides the unreleased approve-login-on-another-device button',
    (tester) async {
      const serverUrl = 'https://example.com';
      const currentUserId = 'current-user-id';
      final scope = serverDomainKeyFromUrl(serverUrl);

      SharedPreferences.setMockInitialValues({
        'profile_display_name::$scope::$currentUserId': 'Current User',
        'profile_description::$scope::$currentUserId': 'About me',
      });

      await tester.pumpWidget(
        _buildProfileApp(
          serverUrl: serverUrl,
          currentUserId: currentUserId,
          remote: _FakeRemoteUserProfileService(
            username: 'Current User',
            description: 'About me',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Approve Login on Another Device'), findsNothing);
      expect(find.text('DEVICE LOGIN'), findsNothing);
    },
  );
}

Widget _buildProfileApp({
  required String serverUrl,
  required String currentUserId,
  required RemoteUserProfileService remote,
}) {
  return ProviderScope(
    overrides: [
      activeServerUrlProvider.overrideWithValue(serverUrl),
      appControllerProvider.overrideWith(_FakeAppController.new),
      myGuildSnapshotProvider.overrideWith((ref) async => null),
      remoteUserProfileServiceProvider.overrideWithValue(remote),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyProfileScreen(
        serverUrl: serverUrl,
        accessToken: 'token',
        currentUserId: currentUserId,
        currentUsername: 'Current User',
      ),
    ),
  );
}

void _setSmallPhoneViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(320, 568);
  addTearDown(() {
    tester.view.resetViewInsets();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
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

class _FakeRemoteUserProfileService extends RemoteUserProfileService {
  _FakeRemoteUserProfileService({
    required String username,
    required String? description,
  }) : _username = username,
       _description = description,
       super();

  String _username;
  String? _description;
  String? lastUsername;
  String? lastDescription;

  @override
  Future<UserProfile> updateMyProfile({
    required String baseUrl,
    required String accessToken,
    String? username,
    String? avatarBase64,
    String? description,
    String? messagePublicKey,
    bool clearAvatar = false,
    bool clearDescription = false,
  }) async {
    if (username != null && username.trim().isNotEmpty) {
      _username = username.trim();
      lastUsername = _username;
    }
    if (clearDescription) {
      _description = null;
      lastDescription = null;
    } else if (description != null) {
      _description = description.trim();
      lastDescription = _description;
    }

    return UserProfile(
      id: 'current-user-id',
      username: _username,
      avatarBase64: null,
      description: _description,
      messagePublicKey: null,
    );
  }
}

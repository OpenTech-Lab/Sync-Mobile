import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/settings/blocked_users_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/services/remote_safety_service.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:mobile/state/safety_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAppController extends AppController {
  @override
  Future<AppState> build() async {
    return const AppState(
      serverUrl: 'https://example.com',
      accessToken: 'token',
      currentUserId: 'owner-id',
      currentUsername: 'owner',
      savedUserId: 'owner-id',
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

class _FakeRemoteSafetyService extends RemoteSafetyService {
  List<BlockedUser> blockedUsers;
  int unblockCallCount = 0;
  String? lastUnblockedUserId;

  _FakeRemoteSafetyService(this.blockedUsers);

  @override
  Future<List<BlockedUser>> listBlockedUsers({
    required String baseUrl,
    required String accessToken,
  }) async {
    return List<BlockedUser>.from(blockedUsers);
  }

  @override
  Future<void> unblockUser({
    required String baseUrl,
    required String accessToken,
    required String userId,
  }) async {
    unblockCallCount += 1;
    lastUnblockedUserId = userId;
    blockedUsers = blockedUsers
        .where((blockedUser) => blockedUser.userId != userId)
        .toList(growable: false);
  }
}

Widget _buildTestApp(_FakeRemoteSafetyService remoteSafetyService) {
  return ProviderScope(
    overrides: [
      appControllerProvider.overrideWith(_FakeAppController.new),
      remoteSafetyServiceProvider.overrideWithValue(remoteSafetyService),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const BlockedUsersPage(serverUrl: 'https://example.com'),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('blocked users page lets the user unblock and removes the row', (
    tester,
  ) async {
    final fakeRemoteSafetyService = _FakeRemoteSafetyService([
      BlockedUser(
        userId: 'friend-a',
        username: 'Friend A',
        avatarBase64: null,
        blockedAt: DateTime.utc(2026, 4, 3, 12, 0),
      ),
    ]);

    await tester.pumpWidget(_buildTestApp(fakeRemoteSafetyService));
    await tester.pumpAndSettle();

    expect(find.text('Friend A'), findsOneWidget);

    await tester.tap(find.text('UNBLOCK').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('UNBLOCK').last);
    await tester.pumpAndSettle();

    expect(fakeRemoteSafetyService.unblockCallCount, 1);
    expect(fakeRemoteSafetyService.lastUnblockedUserId, 'friend-a');
    expect(find.text('Friend A'), findsNothing);
    expect(find.text('No blocked users.'), findsOneWidget);
  });
}

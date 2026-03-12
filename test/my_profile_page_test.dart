import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/my_profile_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/models/user_profile.dart';
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
}

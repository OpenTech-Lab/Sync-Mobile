import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/services/local_chat_repository.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:mobile/state/conversation_messages_controller.dart';
import 'package:mobile/state/user_profile_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home shows a top-right settings button when provided', (
    tester,
  ) async {
    var opened = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeServerUrlProvider.overrideWithValue('https://example.com'),
          chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
          myGuildSnapshotProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeTab(
            serverUrl: 'https://example.com',
            accessToken: 'token',
            currentUserId: 'owner-id',
            currentUsername: 'Owner',
            planetInfo: null,
            onOpenSettings: () {
              opened = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final settingsButton = find.byKey(const ValueKey('home_settings_button'));
    expect(settingsButton, findsOneWidget);

    await tester.tap(settingsButton);
    await tester.pumpAndSettle();

    expect(opened, isTrue);
  });
}

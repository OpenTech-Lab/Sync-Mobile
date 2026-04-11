import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/settings/settings_page.dart';
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

Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      appControllerProvider.overrideWith(_FakeAppController.new),
      remoteSafetyServiceProvider.overrideWithValue(_FakeRemoteSafetyService()),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
      home: SettingsTab(
        serverUrl: 'https://example.com',
        activePartnerId: null,
        onSignOut: () async {},
        onDeleteAccount: () async {},
      ),
    ),
  );
}

class _FakeRemoteSafetyService extends RemoteSafetyService {
  @override
  Future<List<BlockedUser>> listBlockedUsers({
    required String baseUrl,
    required String accessToken,
  }) async {
    return const <BlockedUser>[];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('settings page no longer shows the my planet block', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('settings'), findsOneWidget);
    expect(find.text('MY PLANET'), findsNothing);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('BLOCKED USERS'), findsOneWidget);
  });

  testWidgets('settings page opens blocked users screen from the menu', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('BLOCKED USERS'));
    await tester.pumpAndSettle();

    expect(find.text('Blocked users'), findsOneWidget);
    expect(find.text('No blocked users.'), findsOneWidget);
  });
}

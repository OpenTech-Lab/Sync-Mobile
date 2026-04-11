import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/settings/settings_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:mobile/state/backup_controller.dart';
import 'package:mobile/state/deferred_deletion_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAppController extends AppController {
  int deleteAccountCallCount = 0;

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

  @override
  Future<void> deleteAccount() async {
    deleteAccountCallCount += 1;
  }
}

class _FakeBackupController extends BackupController {
  int deleteBackupDataCallCount = 0;
  int deleteAllLocalDataCallCount = 0;

  @override
  Future<BackupState> build() async {
    return const BackupState(
      enabled: true,
      isBusy: false,
      statusMessage: null,
      autoBackupMessageThreshold: 20,
    );
  }

  @override
  Future<void> deleteBackupData({
    required String baseUrl,
    required String accessToken,
  }) async {
    deleteBackupDataCallCount += 1;
    state = AsyncData(
      (state.value ??
              const BackupState(
                enabled: true,
                isBusy: false,
                statusMessage: null,
                autoBackupMessageThreshold: 20,
              ))
          .copyWith(statusMessage: 'Server backup deleted.'),
    );
  }

  @override
  Future<void> deleteAllLocalData() async {
    deleteAllLocalDataCallCount += 1;
    state = AsyncData(
      (state.value ??
              const BackupState(
                enabled: true,
                isBusy: false,
                statusMessage: null,
                autoBackupMessageThreshold: 20,
              ))
          .copyWith(
            statusMessage: 'All local app data deleted on this device.',
          ),
    );
  }
}

Widget _buildTestApp({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
      home: DangerousActionsPage(
        serverUrl: 'https://example.com',
        activePartnerId: null,
        onSignOut: () async {},
        onDeleteAccount: () async {},
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'dangerous page allows only one active delete countdown and cancel resets it',
    (tester) async {
      final fakeAppController = _FakeAppController();
      final fakeBackupController = _FakeBackupController();
      var fakeNow = DateTime.utc(2026, 3, 13, 0, 0, 0);

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            appControllerProvider.overrideWith(() => fakeAppController),
            backupControllerProvider.overrideWith(() => fakeBackupController),
            deferredDeletionNowProvider.overrideWithValue(() => fakeNow),
            deleteAllPlanetDataDelayProvider.overrideWithValue(
              const Duration(seconds: 12),
            ),
            deleteAccountDelayProvider.overrideWithValue(
              const Duration(seconds: 24),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete all data from this planet'));
      await tester.pumpAndSettle();

      expect(find.text('Deletion executes in 00:00:12.'), findsOneWidget);
      expect(find.text('Delete all data from this planet'), findsNWidgets(2));

      await tester.tap(find.text('Delete this account from this planet'));
      await tester.pumpAndSettle();

      expect(find.text('Deletion executes in 00:00:12.'), findsOneWidget);
      expect(fakeBackupController.deleteBackupDataCallCount, 0);
      expect(fakeBackupController.deleteAllLocalDataCallCount, 0);
      expect(fakeAppController.deleteAccountCallCount, 0);

      await tester.tap(find.text('cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Deletion executes in 00:00:12.'), findsNothing);

      await tester.tap(find.text('Delete this account from this planet'));
      await tester.pumpAndSettle();

      expect(find.text('Deletion executes in 00:00:24.'), findsOneWidget);

      fakeNow = fakeNow.add(const Duration(seconds: 24));
      await tester.pump(const Duration(seconds: 24));
      await tester.pumpAndSettle();

      expect(fakeBackupController.deleteBackupDataCallCount, 1);
      expect(fakeBackupController.deleteAllLocalDataCallCount, 1);
      expect(fakeAppController.deleteAccountCallCount, 1);
    },
  );

  testWidgets('delete-all countdown executes once when the timer expires', (
    tester,
  ) async {
    final fakeAppController = _FakeAppController();
    final fakeBackupController = _FakeBackupController();
    var fakeNow = DateTime.utc(2026, 3, 13, 8, 0, 0);

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          appControllerProvider.overrideWith(() => fakeAppController),
          backupControllerProvider.overrideWith(() => fakeBackupController),
          deferredDeletionNowProvider.overrideWithValue(() => fakeNow),
          deleteAllPlanetDataDelayProvider.overrideWithValue(
            const Duration(seconds: 2),
          ),
          deleteAccountDelayProvider.overrideWithValue(
            const Duration(seconds: 3),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete all data from this planet'));
    await tester.pumpAndSettle();

    expect(find.text('Deletion executes in 00:00:02.'), findsOneWidget);

    fakeNow = fakeNow.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(fakeBackupController.deleteBackupDataCallCount, 1);
    expect(fakeBackupController.deleteAllLocalDataCallCount, 1);
    expect(fakeAppController.deleteAccountCallCount, 0);
    expect(find.text('Deletion executes in 00:00:02.'), findsNothing);
  });
}

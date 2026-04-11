import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/planet/planet_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/models/sticker.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/services/remote_user_profile_service.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:mobile/state/user_profile_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRemoteUserProfileService extends RemoteUserProfileService {
  _FakeRemoteUserProfileService();

  @override
  Future<UserProfile> getUserProfile({
    required String baseUrl,
    required String accessToken,
    required String userId,
  }) async {
    return const UserProfile(
      id: 'artist-id',
      username: 'Sticker Artist',
      avatarBase64: null,
      description: null,
      messagePublicKey: null,
    );
  }
}

class _FakeAppController extends AppController {
  @override
  Future<AppState> build() async {
    return const AppState(
      serverUrl: 'https://example.com',
      accessToken: 'token',
      currentUserId: 'viewer-id',
      currentUsername: 'viewer',
      savedUserId: 'viewer-id',
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('sticker group detail shows author under tab image', (
    tester,
  ) async {
    const tinyPngBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/aMsAAAAASUVORK5CYII=';
    final stickers = <Sticker>[
      Sticker(
        id: 'tab-1',
        uploaderId: 'artist-id',
        groupName: 'Forest Pack',
        name: '__tab__',
        mimeType: 'image/png',
        contentBase64: tinyPngBase64,
        status: 'approved',
        createdAt: DateTime.utc(2026, 3, 13),
      ),
      Sticker(
        id: 'sticker-1',
        uploaderId: 'artist-id',
        groupName: 'Forest Pack',
        name: 'leaf',
        mimeType: 'image/png',
        contentBase64: tinyPngBase64,
        status: 'approved',
        createdAt: DateTime.utc(2026, 3, 13),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(_FakeAppController.new),
          remoteUserProfileServiceProvider.overrideWithValue(
            _FakeRemoteUserProfileService(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StickerGroupDetailPage(
            serverUrl: 'https://example.com',
            accessToken: 'token',
            groupName: 'Forest Pack',
            stickers: stickers,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sticker Artist'), findsOneWidget);
    expect(find.text('Forest Pack'), findsOneWidget);
  });
}

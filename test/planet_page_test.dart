import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/planet/planet_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/models/planet_page_data.dart';
import 'package:mobile/models/realtime_event.dart';
import 'package:mobile/models/server_news.dart';
import 'package:mobile/models/sticker.dart';
import 'package:mobile/services/planet_page_cache_service.dart';
import 'package:mobile/services/server_health_service.dart';
import 'package:mobile/services/server_news_service.dart';
import 'package:mobile/services/sticker_cache_service.dart';
import 'package:mobile/services/sticker_service.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:mobile/state/notification_controller.dart';
import 'package:mobile/state/planet_page_controller.dart';
import 'package:mobile/state/realtime_sync_controller.dart';
import 'package:mobile/state/sticker_controller.dart';
import 'package:mobile/state/unread_counts_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _serverUrl = 'https://example.com';

class _FakeHealthService extends ServerHealthService {
  _FakeHealthService(this._responses);

  final Map<String, PlanetInfo> _responses;
  int validateCallCount = 0;

  @override
  Future<PlanetInfo> validate(String baseUrl) async {
    validateCallCount += 1;
    final response = _responses[baseUrl];
    if (response == null) {
      throw StateError('No fake planet info for $baseUrl');
    }
    return response;
  }
}

class _FakeNewsService extends ServerNewsService {
  _FakeNewsService(this._items);

  final List<ServerNewsItem> _items;
  int listCallCount = 0;

  @override
  Future<List<ServerNewsItem>> listNews({
    required String baseUrl,
    required String accessToken,
    int limit = 30,
  }) async {
    listCallCount += 1;
    return _items;
  }
}

class _InMemoryPlanetPageCacheService extends PlanetPageCacheService {
  final Map<String, PlanetPageData?> _cacheByServer = {};

  @override
  Future<PlanetPageData?> read(String serverUrl) async {
    return _cacheByServer[serverUrl];
  }

  @override
  Future<void> write(String serverUrl, PlanetPageData data) async {
    _cacheByServer[serverUrl] = data;
  }
}

class _FakeStickerService extends StickerService {
  _FakeStickerService(this._stickers);

  final List<Sticker> _stickers;
  int syncCallCount = 0;

  @override
  Future<List<Sticker>> syncAll({
    required String baseUrl,
    required String accessToken,
  }) async {
    syncCallCount += 1;
    return _stickers;
  }
}

class _ReconnectLog {
  int ensureFreshCallCount = 0;
  int fetchAltchaChallengeCallCount = 0;
  int loginCallCount = 0;
  String? lastRealtimeAccessToken;
  String? lastNotificationAccessToken;
  String? lastUnreadAccessToken;
}

class _ReconnectAppController extends AppController {
  _ReconnectAppController(this.log);

  final _ReconnectLog log;

  @override
  Future<AppState> build() async {
    return const AppState(
      serverUrl: _serverUrl,
      accessToken: '',
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
  Future<String?> ensureFreshAccessToken() async {
    log.ensureFreshCallCount += 1;
    return null;
  }

  @override
  Future<Map<String, dynamic>?> fetchAltchaChallenge(String serverUrl) async {
    log.fetchAltchaChallengeCallCount += 1;
    return null;
  }

  @override
  Future<void> loginWithDeviceIdentity({String? altchaPayload}) async {
    log.loginCallCount += 1;
    final current = state.value!;
    state = AsyncData(
      current.copyWith(
        accessToken: 'reconnected-token',
        currentUserId: 'owner-id',
        currentUsername: 'owner',
        isSubmitting: false,
        clearAuthError: true,
      ),
    );
  }
}

class _FakeRealtimeSyncController extends RealtimeSyncController {
  _FakeRealtimeSyncController(this.log);

  final _ReconnectLog log;

  @override
  Future<RealtimeSyncState> build() async {
    return const RealtimeSyncState(
      status: RealtimeConnectionStatus.disconnected,
      error: null,
      typingPartnerIds: <String>{},
    );
  }

  @override
  Future<void> connect({
    required String baseUrl,
    required Future<String?> Function() accessTokenProvider,
    required String currentUserId,
  }) async {
    log.lastRealtimeAccessToken = await accessTokenProvider();
    state = const AsyncData(
      RealtimeSyncState(
        status: RealtimeConnectionStatus.connected,
        error: null,
        typingPartnerIds: <String>{},
      ),
    );
  }
}

class _FakeNotificationController extends NotificationController {
  _FakeNotificationController(this.log);

  final _ReconnectLog log;

  @override
  Future<NotificationState> build() async {
    return const NotificationState(
      initialized: false,
      deviceToken: null,
      status: null,
      syncedServerDomain: null,
    );
  }

  @override
  Future<void> initialize({
    required String baseUrl,
    required String accessToken,
  }) async {
    log.lastNotificationAccessToken = accessToken;
    state = const AsyncData(
      NotificationState(
        initialized: true,
        deviceToken: 'device-token',
        status: 'Push token synced.',
        syncedServerDomain: 'example.com',
      ),
    );
  }
}

class _FakeUnreadCountsController extends UnreadCountsController {
  _FakeUnreadCountsController(this.log);

  final _ReconnectLog log;

  @override
  Future<Map<String, int>> build() async {
    return <String, int>{};
  }

  @override
  Future<void> refresh({
    required String baseUrl,
    required String accessToken,
  }) async {
    log.lastUnreadAccessToken = accessToken;
    state = const AsyncData(<String, int>{});
  }
}

class _InMemoryStickerCacheService extends StickerCacheService {
  final Map<String, List<Sticker>> _cacheByServer = {};

  @override
  Future<List<Sticker>> read(String serverUrl) async {
    return _cacheByServer[serverUrl] ?? const <Sticker>[];
  }

  @override
  Future<void> write(String serverUrl, List<Sticker> stickers) async {
    _cacheByServer[serverUrl] = List<Sticker>.from(stickers);
  }
}

PlanetInfo _planet({
  required String baseUrl,
  required String host,
  required String name,
}) {
  return PlanetInfo(
    baseUrl: baseUrl,
    host: host,
    scheme: 'https',
    instanceName: name,
    instanceDescription: '$name description',
    instanceImageUrl: null,
    memberCount: 12,
    linkedPlanets: const <String>[],
    instanceDomain: host,
    countryCode: 'JP',
    countryName: 'Japan',
    serverCreatedAt: DateTime.utc(2026, 3, 1),
    healthStatus: 'ok',
    latencyMs: 12,
    checkedAt: DateTime.utc(2026, 3, 13, 8),
    registrationRequiresApproval: false,
  );
}

ServerNewsItem _news(String id, String title) {
  return ServerNewsItem(
    id: id,
    title: title,
    summary: '$title summary',
    markdownContent: '$title body',
    publishedAt: DateTime.utc(2026, 3, 13, 9),
    updatedAt: null,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'planet tab opens from cache and only reloads on pull-to-refresh',
    (tester) async {
      final cache = _InMemoryPlanetPageCacheService();
      await cache.write(
        _serverUrl,
        PlanetPageData(
          currentPlanet: _planet(
            baseUrl: _serverUrl,
            host: 'example.com',
            name: 'Cached Planet',
          ),
          planets: const <PlanetInfo>[],
          news: [_news('cached-1', 'Cached headline')],
        ),
      );
      final health = _FakeHealthService({
        _serverUrl: _planet(
          baseUrl: _serverUrl,
          host: 'example.com',
          name: 'Remote Planet',
        ),
      });
      final newsService = _FakeNewsService([
        _news('remote-1', 'Remote headline'),
      ]);
      final stickerCache = _InMemoryStickerCacheService();
      final stickerService = _FakeStickerService(const <Sticker>[]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerUrlProvider.overrideWithValue(_serverUrl),
            planetPageCacheServiceProvider.overrideWithValue(cache),
            planetPageHealthServiceProvider.overrideWithValue(health),
            planetPageNewsServiceProvider.overrideWithValue(newsService),
            stickerCacheServiceProvider.overrideWithValue(stickerCache),
            stickerServiceProvider.overrideWithValue(stickerService),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PlanetTab(serverUrl: _serverUrl, accessToken: 'token'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cached Planet'), findsOneWidget);
      expect(find.text('Cached headline'), findsOneWidget);
      expect(health.validateCallCount, 0);
      expect(newsService.listCallCount, 0);
      expect(stickerService.syncCallCount, 0);

      await tester.drag(
        find.byKey(const ValueKey('planet_page_scroll')),
        const Offset(0, 320),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Remote Planet'), findsOneWidget);
      expect(find.text('Remote headline'), findsOneWidget);
      expect(find.text('Cached headline'), findsNothing);
      expect(health.validateCallCount, 1);
      expect(newsService.listCallCount, 1);
      expect(stickerService.syncCallCount, 1);
    },
  );

  testWidgets(
    'my planet reconnect button reauthenticates and restarts services',
    (tester) async {
      final cache = _InMemoryPlanetPageCacheService();
      await cache.write(
        _serverUrl,
        PlanetPageData(
          currentPlanet: _planet(
            baseUrl: _serverUrl,
            host: 'example.com',
            name: 'Cached Planet',
          ),
          planets: const <PlanetInfo>[],
          news: [_news('cached-1', 'Cached headline')],
        ),
      );
      final health = _FakeHealthService({
        _serverUrl: _planet(
          baseUrl: _serverUrl,
          host: 'example.com',
          name: 'Remote Planet',
        ),
      });
      final newsService = _FakeNewsService([
        _news('remote-1', 'Remote headline'),
      ]);
      final stickerCache = _InMemoryStickerCacheService();
      final stickerService = _FakeStickerService(const <Sticker>[]);
      final reconnectLog = _ReconnectLog();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerUrlProvider.overrideWithValue(_serverUrl),
            appControllerProvider.overrideWith(
              () => _ReconnectAppController(reconnectLog),
            ),
            realtimeSyncControllerProvider.overrideWith(
              () => _FakeRealtimeSyncController(reconnectLog),
            ),
            notificationControllerProvider.overrideWith(
              () => _FakeNotificationController(reconnectLog),
            ),
            unreadCountsProvider.overrideWith(
              () => _FakeUnreadCountsController(reconnectLog),
            ),
            planetPageCacheServiceProvider.overrideWithValue(cache),
            planetPageHealthServiceProvider.overrideWithValue(health),
            planetPageNewsServiceProvider.overrideWithValue(newsService),
            stickerCacheServiceProvider.overrideWithValue(stickerCache),
            stickerServiceProvider.overrideWithValue(stickerService),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PlanetTab(serverUrl: _serverUrl, accessToken: ''),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cached Planet'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('planet_reconnect_button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('planet_reconnect_button')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(reconnectLog.ensureFreshCallCount, greaterThanOrEqualTo(2));
      expect(reconnectLog.fetchAltchaChallengeCallCount, 1);
      expect(reconnectLog.loginCallCount, 1);
      expect(reconnectLog.lastRealtimeAccessToken, 'reconnected-token');
      expect(reconnectLog.lastNotificationAccessToken, 'reconnected-token');
      expect(reconnectLog.lastUnreadAccessToken, 'reconnected-token');
      expect(health.validateCallCount, 1);
      expect(newsService.listCallCount, 1);
      expect(stickerService.syncCallCount, 1);
      expect(find.text('Remote Planet'), findsOneWidget);
      expect(find.text('Remote headline'), findsOneWidget);
    },
  );
}

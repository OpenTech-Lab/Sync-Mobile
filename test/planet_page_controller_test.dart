import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/planet_page_data.dart';
import 'package:mobile/models/server_news.dart';
import 'package:mobile/services/planet_page_cache_service.dart';
import 'package:mobile/services/server_health_service.dart';
import 'package:mobile/services/server_news_service.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:mobile/state/planet_page_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAppController extends AppController {
  _FakeAppController({this.accessToken});

  final String? accessToken;

  @override
  Future<AppState> build() async {
    return AppState(
      serverUrl: 'https://example.com',
      accessToken: accessToken,
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
}

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

  @override
  Future<void> clear(String serverUrl) async {
    _cacheByServer.remove(serverUrl);
  }
}

PlanetInfo _planet({
  required String baseUrl,
  required String host,
  required String name,
  List<String> linkedPlanets = const <String>[],
}) {
  return PlanetInfo(
    baseUrl: baseUrl,
    host: host,
    scheme: 'https',
    instanceName: name,
    instanceDescription: '$name description',
    instanceImageUrl: null,
    memberCount: 12,
    linkedPlanets: linkedPlanets,
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
  const serverUrl = 'https://example.com';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'planet page controller paints cached data immediately, then revalidates in the background',
    () async {
      final cache = _InMemoryPlanetPageCacheService();
      await cache.write(
        serverUrl,
        PlanetPageData(
          currentPlanet: _planet(
            baseUrl: serverUrl,
            host: 'example.com',
            name: 'Cached Planet',
          ),
          planets: const <PlanetInfo>[],
          news: [_news('cached-1', 'Cached headline')],
        ),
      );
      final health = _FakeHealthService({
        serverUrl: _planet(
          baseUrl: serverUrl,
          host: 'example.com',
          name: 'Remote Planet',
        ),
      });
      final newsService = _FakeNewsService([
        _news('remote-1', 'Remote headline'),
      ]);

      final container = ProviderContainer(
        overrides: [
          activeServerUrlProvider.overrideWithValue(serverUrl),
          planetPageCacheServiceProvider.overrideWithValue(cache),
          planetPageHealthServiceProvider.overrideWithValue(health),
          planetPageNewsServiceProvider.overrideWithValue(newsService),
          appControllerProvider.overrideWith(
            () => _FakeAppController(accessToken: 'token'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final initial = await container.read(
        planetPageControllerProvider.future,
      );
      expect(initial?.currentPlanet?.instanceName, 'Cached Planet');
      expect(initial?.news.single.title, 'Cached headline');

      // The background revalidation is fire-and-forget; wait for it to land.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final revalidated = container
          .read(planetPageControllerProvider)
          .valueOrNull;
      expect(revalidated?.currentPlanet?.instanceName, 'Remote Planet');
      expect(revalidated?.news.single.title, 'Remote headline');
      expect(health.validateCallCount, 1);
      expect(newsService.listCallCount, 1);

      final cachedAfterRevalidate = await cache.read(serverUrl);
      expect(cachedAfterRevalidate?.currentPlanet?.instanceName, 'Remote Planet');
      expect(cachedAfterRevalidate?.news.single.title, 'Remote headline');
    },
  );

  test(
    'planet page controller skips background revalidation without an access token',
    () async {
      final cache = _InMemoryPlanetPageCacheService();
      await cache.write(
        serverUrl,
        PlanetPageData(
          currentPlanet: _planet(
            baseUrl: serverUrl,
            host: 'example.com',
            name: 'Cached Planet',
          ),
          planets: const <PlanetInfo>[],
          news: [_news('cached-1', 'Cached headline')],
        ),
      );
      final health = _FakeHealthService({
        serverUrl: _planet(
          baseUrl: serverUrl,
          host: 'example.com',
          name: 'Remote Planet',
        ),
      });
      final newsService = _FakeNewsService([
        _news('remote-1', 'Remote headline'),
      ]);

      final container = ProviderContainer(
        overrides: [
          activeServerUrlProvider.overrideWithValue(serverUrl),
          planetPageCacheServiceProvider.overrideWithValue(cache),
          planetPageHealthServiceProvider.overrideWithValue(health),
          planetPageNewsServiceProvider.overrideWithValue(newsService),
          appControllerProvider.overrideWith(
            () => _FakeAppController(accessToken: null),
          ),
        ],
      );
      addTearDown(container.dispose);

      final initial = await container.read(
        planetPageControllerProvider.future,
      );
      expect(initial?.currentPlanet?.instanceName, 'Cached Planet');

      await Future<void>.delayed(Duration.zero);

      expect(health.validateCallCount, 0);
      expect(newsService.listCallCount, 0);
    },
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/planet_page_data.dart';
import '../services/planet_page_cache_service.dart';
import '../services/server_health_service.dart';
import '../services/server_news_service.dart';
import '../services/server_preferences.dart';
import 'app_controller.dart';

final planetPageCacheServiceProvider = Provider<PlanetPageCacheService>((ref) {
  return PlanetPageCacheService();
});

final planetPageHealthServiceProvider = Provider<ServerHealthService>((ref) {
  return ServerHealthService();
});

final planetPageNewsServiceProvider = Provider<ServerNewsService>((ref) {
  return ServerNewsService();
});

final planetPageControllerProvider =
    AsyncNotifierProvider<PlanetPageController, PlanetPageData?>(
      PlanetPageController.new,
    );

class PlanetPageController extends AsyncNotifier<PlanetPageData?> {
  final _serverPreferences = ServerPreferences();

  PlanetPageCacheService get _cache => ref.read(planetPageCacheServiceProvider);
  ServerHealthService get _healthService =>
      ref.read(planetPageHealthServiceProvider);
  ServerNewsService get _newsService => ref.read(planetPageNewsServiceProvider);

  @override
  Future<PlanetPageData?> build() async {
    final serverUrl = ref.watch(activeServerUrlProvider);
    if (serverUrl == null || serverUrl.isEmpty) {
      return null;
    }

    final cached = await _cache.read(serverUrl);
    if (cached != null) {
      return cached;
    }

    final appState = ref.watch(appControllerProvider).valueOrNull;
    final accessToken = appState?.accessToken?.trim();
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final baseUrl = appState?.serverUrl?.trim();
    return _fetchAndStore(
      baseUrl: baseUrl == null || baseUrl.isEmpty ? serverUrl : baseUrl,
      accessToken: accessToken,
    );
  }

  Future<PlanetPageData> refresh({
    required String baseUrl,
    required String accessToken,
  }) async {
    final previous = state.valueOrNull;
    try {
      return await _fetchAndStore(baseUrl: baseUrl, accessToken: accessToken);
    } catch (error, stackTrace) {
      if (previous == null) {
        state = AsyncError(error, stackTrace);
      } else {
        state = AsyncData(previous);
      }
      rethrow;
    }
  }

  Future<PlanetPageData> _fetchAndStore({
    required String baseUrl,
    required String accessToken,
  }) async {
    final current = await _healthService.validate(baseUrl);

    final planets = <PlanetInfo>[];
    for (final url in current.linkedPlanets.take(20)) {
      try {
        final info = await _healthService.validate(url);
        planets.add(info);
      } catch (_) {
        // Skip offline or invalid planets.
      }
    }

    final news = await _newsService.listNews(
      baseUrl: baseUrl,
      accessToken: accessToken,
      limit: 30,
    );

    final next = PlanetPageData(
      currentPlanet: current,
      planets: planets,
      news: news,
    );

    await _cache.write(baseUrl, next);
    await _serverPreferences.writePlanetInfo(
      serverUrl: current.baseUrl,
      planetInfo: current,
    );
    state = AsyncData(next);
    return next;
  }
}

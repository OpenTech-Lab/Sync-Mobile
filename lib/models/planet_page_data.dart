import 'server_news.dart';
import '../services/server_health_service.dart';

class PlanetPageData {
  const PlanetPageData({
    required this.currentPlanet,
    required this.planets,
    required this.news,
  });

  static const empty = PlanetPageData(
    currentPlanet: null,
    planets: <PlanetInfo>[],
    news: <ServerNewsItem>[],
  );

  final PlanetInfo? currentPlanet;
  final List<PlanetInfo> planets;
  final List<ServerNewsItem> news;

  factory PlanetPageData.fromMap(Map<String, dynamic> map) {
    final currentPlanetMap = map['current_planet'];
    final rawPlanets = map['planets'];
    final rawNews = map['news'];

    return PlanetPageData(
      currentPlanet: currentPlanetMap is Map<String, dynamic>
          ? PlanetInfo.fromMap(currentPlanetMap)
          : null,
      planets: rawPlanets is List
          ? rawPlanets
                .whereType<Map<String, dynamic>>()
                .map(PlanetInfo.fromMap)
                .toList(growable: false)
          : const <PlanetInfo>[],
      news: rawNews is List
          ? rawNews
                .whereType<Map<String, dynamic>>()
                .map(ServerNewsItem.fromMap)
                .toList(growable: false)
          : const <ServerNewsItem>[],
    );
  }

  Map<String, Object?> toMap() {
    return {
      'current_planet': currentPlanet?.toMap(),
      'planets': planets
          .map((planet) => planet.toMap())
          .toList(growable: false),
      'news': news.map((item) => item.toMap()).toList(growable: false),
    };
  }
}
